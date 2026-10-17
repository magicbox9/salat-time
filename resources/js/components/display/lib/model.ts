import { dayMinutes } from '@/lib/prayer-time';
import type { DayTimes } from '@/types/mosque';
import type {
    DisplayPayload,
    DisplaySettings,
    ScreenPrayer,
    Simulation,
} from '../types';
import type { Phase, PrayerEvent } from './schedule';
import { NORMAL, dayEvents, phaseAt, simulate } from './schedule';
import type { ZoneNow } from './zone';
import { addDays, hhmm, minutesUntil, zoneNow } from './zone';

export type RowState = 'passed' | 'current' | 'next' | 'upcoming';

/** One line of the prayer table. */
export type Row = {
    prayer: ScreenPrayer;
    time: string;
    iqama: string | null;
    state: RowState;
    /** Tomorrow's time, shown once today's prayer has passed (Fajr after Isha). */
    tomorrow: boolean;
};

export type ScreenModel = {
    zone: ZoneNow;
    day: DayTimes | null;
    rows: Row[];
    shuruq: string | null;
    next: { event: PrayerEvent; remaining: number } | null;
    phase: Phase;
    isFriday: boolean;
    /** Jumu'a times to show on the Jumu'a tile. */
    jumua: string[];
    /** Night dimming is on now (only while nothing is happening). */
    dimmed: boolean;
    /** Morning adhkar from Fajr until Asr, evening ones after. */
    period: 'morning' | 'evening';
    /** For the living sky (minutes of the day). */
    sky: { fajr: number; shuruq: number; maghrib: number; isha: number } | null;
    settings: DisplaySettings;
};

const isFridayOn = (iso: string) =>
    new Date(`${iso}T12:00:00Z`).getUTCDay() === 5;

function inWindow(minutes: number, from: string, to: string): boolean {
    const start = hhmm(from);
    const end = hhmm(to);

    if (start === null || end === null || start === end) {
        return false;
    }

    return start < end
        ? minutes >= start && minutes < end
        : minutes >= start || minutes < end;
}

/** The next Friday's Dhuhr when the mosque holds Jumu'a at Dhuhr time. */
function jumuaTimes(payload: DisplayPayload, from: string): string[] {
    if (!payload.jumua.as_dhuhr) {
        return payload.jumua.times;
    }

    const friday = payload.days.find(
        (d) => d.date >= from && isFridayOn(d.date),
    );

    return friday ? [friday.times.dhuhr] : [];
}

/**
 * Everything a theme draws, computed once a second from the published days,
 * the settings and the mosque's own clock.
 */
export function buildModel(
    payload: DisplayPayload,
    settings: DisplaySettings,
    now: Date,
    simulation: Simulation | null = null,
): ScreenModel {
    const zone = zoneNow(payload.timezone, now);
    const byDate = new Map(payload.days.map((d) => [d.date, d]));

    if (payload.yesterday) {
        byDate.set(payload.yesterday.date, payload.yesterday);
    }

    const day = byDate.get(zone.date) ?? null;
    const yesterday = byDate.get(addDays(zone.date, -1)) ?? null;
    const tomorrow = byDate.get(addDays(zone.date, 1)) ?? null;
    const isFriday = isFridayOn(zone.date);
    const events: PrayerEvent[] = [
        ...(yesterday
            ? dayEvents(yesterday, -1, isFridayOn(yesterday.date))
            : []),
        ...(day ? dayEvents(day, 0, isFriday) : []),
        ...(tomorrow ? dayEvents(tomorrow, 1, isFridayOn(tomorrow.date)) : []),
    ];
    const upcoming = events.find((e) => e.adhan > zone.minutes) ?? null;
    let phase = day ? phaseAt(events, zone.minutes, settings) : NORMAL;
    let effective = settings;

    if (simulation && day) {
        const prayer = upcoming?.prayer ?? 'dhuhr';
        const sim = simulate(
            simulation,
            now.getTime(),
            zone.minutes,
            settings,
            prayer,
        );
        effective = sim.settings;
        phase = phaseAt(sim.events, zone.minutes, sim.settings);
    }

    const focus =
        phase.kind !== 'normal' && phase.kind !== 'approaching'
            ? phase.event
            : null;
    const nextEvent = phase.kind === 'approaching' ? phase.event : upcoming;
    const todays = events.filter((e) => e.offset === 0);
    const rows: Row[] = todays.map((e) => {
        const passed = e.adhan <= zone.minutes;
        const tomorrowEvent =
            passed &&
            nextEvent &&
            nextEvent.offset === 1 &&
            nextEvent.prayer === e.prayer
                ? nextEvent
                : null;
        const shown = tomorrowEvent ?? e;
        let state: RowState = passed ? 'passed' : 'upcoming';

        if (focus && focus.prayer === e.prayer) {
            state = 'current';
        } else if (
            nextEvent &&
            nextEvent.prayer === e.prayer &&
            (nextEvent.offset === 0 || tomorrowEvent)
        ) {
            state = 'next';
        }

        return {
            prayer: e.prayer,
            time: shown.time,
            iqama: shown.iqamaTime,
            state,
            tomorrow: tomorrowEvent !== null,
        };
    });

    const minutes = day ? dayMinutes(day) : null;
    const asr = minutes?.asr ?? 15 * 60;
    const fajr = minutes?.fajr ?? 5 * 60;

    return {
        zone,
        day,
        rows,
        shuruq: day?.times.shuruq ?? null,
        next: nextEvent
            ? {
                  event: nextEvent,
                  remaining: minutesUntil(
                      payload.timezone,
                      now,
                      zone.date,
                      nextEvent.adhan,
                  ),
              }
            : null,
        phase,
        isFriday,
        jumua: jumuaTimes(payload, zone.date),
        dimmed:
            settings.night_dim &&
            phase.kind === 'normal' &&
            inWindow(zone.minutes, settings.night_from, settings.night_to),
        period:
            zone.minutes >= fajr && zone.minutes < asr ? 'morning' : 'evening',
        sky: minutes
            ? {
                  fajr: minutes.fajr,
                  shuruq: minutes.shuruq,
                  maghrib: minutes.maghrib,
                  isha: minutes.isha,
              }
            : null,
        settings: effective,
    };
}
