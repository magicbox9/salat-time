import { dateInZone } from '@/components/discover/format';
import { dayMinutes, minutesInZone, toMinutes } from '@/lib/prayer-time';
import type { DayTimes } from '@/types/mosque';

/**
 * How long after an Isha published past midnight ("00:02") the evening's
 * prayers stay on screen: its adhan reminder, then a calm moment (at least
 * until its iqama). Never past the new day's Fajr.
 */
const NIGHT_HOLD_MINUTES = 20;

export type PrayerDay = {
    today: DayTimes;
    tomorrow: DayTimes | null;
    /**
     * Added to the minutes since the mosque's midnight to count on today's
     * clock: 1440 while the evening before still holds the night, -1440
     * just before a midnight the device has not reached yet, else 0.
     */
    offset: number;
};

/** "2026-06-20" → "2026-06-21". */
function dayAfter(iso: string): string {
    const [y, m, d] = iso.split('-').map(Number);

    return new Date(Date.UTC(y, m - 1, d + 1)).toISOString().slice(0, 10);
}

/**
 * An iqama ("HH:MM") as minutes on its adhan's clock: an iqama a little
 * past midnight follows its adhan (Isha 23:55 → iqama 00:05 = 1445).
 */
export function iqamaMinutes(iqama: string, adhan: number): number | null {
    const value = toMinutes(iqama);

    if (Number.isNaN(value)) {
        return null;
    }

    const onDay = value + Math.floor(adhan / 1440) * 1440;

    // Only a wrap across midnight: an iqama well before its adhan is a typo, not tomorrow.
    return onDay < adhan - 720 ? onDay + 1440 : onDay;
}

/**
 * The minute (after the new day's midnight) until which the evening
 * before keeps the night, or null when its Isha is not after midnight.
 */
function nightEnd(evening: DayTimes, morning: DayTimes): number | null {
    const minutes = dayMinutes(evening);
    const ishaClock = toMinutes(evening.times.isha);

    // An Isha past Fajr on the clock ("09:45") is a typo, never a night prayer.
    if (minutes.isha < 1440 || ishaClock >= toMinutes(evening.times.fajr)) {
        return null;
    }

    const iqama = evening.iqama.isha
        ? iqamaMinutes(evening.iqama.isha, minutes.isha)
        : null;
    const end = Math.max(
        minutes.isha + NIGHT_HOLD_MINUTES,
        iqama === null ? 0 : iqama + 1,
    );

    return Math.min(end - 1440, toMinutes(morning.times.fajr));
}

/**
 * The prayer day that applies now, from the published days the page holds
 * (the evening before when it still matters, today, tomorrow). A page left
 * open past the mosque's midnight moves on to the next day, except while
 * an Isha published after midnight still belongs to the evening before.
 * Days the page does not hold are never guessed: null.
 */
export function prayerDay(
    days: (DayTimes | null | undefined)[],
    timezone: string,
    now: Date,
): PrayerDay | null {
    const list = days.filter((day): day is DayTimes => !!day);
    const date = dateInZone(timezone, now);
    const index = list.findIndex((day) => day.date === date);
    const following = (day: DayTimes) => {
        const next = list[list.indexOf(day) + 1] ?? null;

        return next && next.date === dayAfter(day.date) ? next : null;
    };

    if (index === -1) {
        // A device clock a little behind the server's, just before midnight:
        // the first day held is still tomorrow, counted on its own clock.
        if (date && list.length > 0 && dayAfter(date) === list[0].date) {
            return {
                today: list[0],
                tomorrow: following(list[0]),
                offset: -1440,
            };
        }

        return null;
    }

    const day = list[index];
    const evening = index > 0 ? list[index - 1] : null;

    if (evening && dayAfter(evening.date) === day.date) {
        const end = nightEnd(evening, day);

        if (end !== null && minutesInZone(timezone, now) < end) {
            return { today: evening, tomorrow: day, offset: 1440 };
        }
    }

    return { today: day, tomorrow: following(day), offset: 0 };
}
