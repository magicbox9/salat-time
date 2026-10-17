import { minutesInZone, toMinutes } from '@/lib/prayer-time';
import type { DayTimes, PrayerName } from '@/types/mosque';
import { PRAYERS } from '@/types/mosque';
import { hubDayMinutes, iqamaMinutes } from './prayer-day';
import type { SkyDay } from './sky';
import type { DayView, RowState, TimeRow } from './types';
import { instantAt } from './zone-time';

/** The prayer at the earliest minute that passes `test` (day order on a tie). */
function earliest(
    minutes: Record<PrayerName, number>,
    test: (at: number) => boolean,
): PrayerName | undefined {
    return PRAYERS.filter((prayer) => test(minutes[prayer])).sort(
        (a, b) => minutes[a] - minutes[b],
    )[0];
}

/**
 * Today's six published times as rows with their live state: passed,
 * current (its time has come), next (the countdown target) or upcoming.
 * After Isha the next prayer is tomorrow's Fajr, shown on the Fajr row.
 * `offset` counts "now" on today's clock (see prayerDay): +1440 while an
 * Isha published after midnight still holds the evening's night.
 */
export function buildDayView(
    today: DayTimes,
    tomorrow: DayTimes | null,
    timezone: string,
    now: Date,
    offset = 0,
): DayView {
    const nowMinutes = minutesInZone(timezone, now) + offset;
    const minutes = hubDayMinutes(today);
    // By time, not by name: rows published out of order still count right.
    const upcoming = earliest(minutes, (at) => at > nowMinutes);
    const fajrTomorrow = tomorrow
        ? 1440 + toMinutes(tomorrow.times.fajr)
        : null;
    const nextTomorrow =
        upcoming === undefined &&
        fajrTomorrow !== null &&
        fajrTomorrow > nowMinutes;
    const nextPrayer: PrayerName | null =
        upcoming ?? (nextTomorrow ? 'fajr' : null);
    const nextAt = upcoming
        ? minutes[upcoming]
        : nextTomorrow
          ? fajrTomorrow
          : null;
    // Counted between real instants: right across a DST change too.
    const until = (date: string, at: number): number => {
        const instant = instantAt(date, at, timezone);

        return instant === null
            ? at - nowMinutes
            : Math.max(0, (instant - now.getTime()) / 60_000);
    };
    // The latest time already reached (stable sort: day order on a tie).
    const reached = PRAYERS.filter(
        (prayer) => minutes[prayer] <= nowMinutes,
    ).sort((a, b) => minutes[a] - minutes[b]);
    const last = reached.at(-1) ?? null;
    const current = last === 'shuruq' ? null : last;

    const rows: TimeRow[] = PRAYERS.map((prayer) => {
        const isNext = nextPrayer === prayer;
        const shownTomorrow = isNext && nextTomorrow;
        let state: RowState;

        if (isNext) {
            state = 'next';
        } else if (current === prayer) {
            state = 'current';
        } else {
            state = minutes[prayer] <= nowMinutes ? 'passed' : 'upcoming';
        }

        const iqama =
            prayer === 'shuruq' || shownTomorrow
                ? null
                : (today.iqama[prayer] ?? null);

        return {
            prayer,
            time:
                shownTomorrow && tomorrow
                    ? tomorrow.times.fajr
                    : today.times[prayer],
            minutes: minutes[prayer],
            iqama,
            iqamaAt: iqama ? iqamaMinutes(iqama, minutes[prayer]) : null,
            jumua: prayer === 'dhuhr' ? today.jumua : null,
            state,
            // Past midnight (the evening's Isha still on screen) that Fajr is
            // already today's on the calendar: no "Tomorrow" label.
            tomorrow: shownTomorrow && nowMinutes < 1440,
        };
    });

    return {
        today,
        rows,
        nowMinutes,
        next: rows.find((row) => row.state === 'next') ?? null,
        untilNext: nextAt === null ? null : until(today.date, nextAt),
        timezone,
    };
}

/** The prayers that have an adhan (Shuruq has none). */
export function hasAdhan(prayer: PrayerName): boolean {
    return prayer !== 'shuruq';
}

/**
 * Where "now" sits among the rows, in row units (0 = top of the first row,
 * rows.length = bottom of the last), for the timeline's sun marker.
 */
export function timelinePosition(view: DayView): number {
    const { rows, nowMinutes } = view;
    const count = rows.length;
    const first = rows[0].minutes;
    const last = rows[count - 1].minutes;

    if (nowMinutes < first) {
        return 0.5 * Math.max(0, nowMinutes / Math.max(1, first));
    }

    for (let i = 0; i < count - 1; i++) {
        const a = rows[i].minutes;
        const b = rows[i + 1].minutes;

        if (nowMinutes >= a && nowMinutes < b) {
            return i + 0.5 + (nowMinutes - a) / Math.max(1, b - a);
        }
    }

    const nightEnd = 1440 + first;
    const fraction = (nowMinutes - last) / Math.max(1, nightEnd - last);

    return count - 0.5 + 0.5 * Math.min(1, Math.max(0, fraction));
}

/** Whether the sun is up (between sunrise and Maghrib). */
export function isDaytime(view: DayView): boolean {
    const shuruq = view.rows.find((row) => row.prayer === 'shuruq');
    const maghrib = view.rows.find((row) => row.prayer === 'maghrib');

    return (
        !!shuruq &&
        !!maghrib &&
        view.nowMinutes >= shuruq.minutes &&
        view.nowMinutes < maghrib.minutes
    );
}

/** Today's minutes by prayer (even when the Fajr row shows tomorrow's time). */
export function minutesOf(view: DayView): Record<PrayerName, number> {
    return hubDayMinutes(view.today);
}

/** The four moments that colour the sky, kept in order for drawing. */
export function skyDayOf(view: DayView): SkyDay {
    const m = minutesOf(view);
    const maghrib = Math.max(m.maghrib, m.shuruq + 1);

    return {
        fajr: Math.min(m.fajr, m.shuruq - 1),
        shuruq: m.shuruq,
        maghrib,
        isha: Math.max(m.isha, maghrib + 1),
    };
}
