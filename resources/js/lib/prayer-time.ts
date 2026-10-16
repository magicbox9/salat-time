import type { DayTimes, PrayerName } from '@/types/mosque';

/** "HH:MM" → minutes after midnight. */
export function toMinutes(hhmm: string): number {
    const [h, m] = hhmm.split(':').map(Number);

    return h * 60 + m;
}

/** Minutes after midnight in a time zone, for an instant (default: now). */
export function minutesInZone(timeZone: string, at: Date = new Date()): number {
    const parts = new Intl.DateTimeFormat('en-GB', {
        timeZone,
        hour: '2-digit',
        minute: '2-digit',
        second: '2-digit',
        hourCycle: 'h23',
    }).formatToParts(at);
    const get = (type: string) =>
        Number(parts.find((p) => p.type === type)?.value ?? 0);

    return get('hour') * 60 + get('minute') + get('second') / 60;
}

export type NextPrayer = {
    prayer: PrayerName;
    time: string;
    tomorrow: boolean;
    /** Minutes from now (may include seconds as a fraction). */
    inMinutes: number;
};

const COUNTED: PrayerName[] = ['fajr', 'shuruq', 'dhuhr', 'asr', 'maghrib', 'isha'];

/** The next event after now, using tomorrow's Fajr after Isha. */
export function nextPrayer(
    today: DayTimes | null,
    tomorrow: DayTimes | null,
    timeZone: string,
    at: Date = new Date(),
): NextPrayer | null {
    if (!today) {
        return null;
    }

    const now = minutesInZone(timeZone, at);

    for (const prayer of COUNTED) {
        const time = today.times[prayer];

        if (time && toMinutes(time) > now) {
            return { prayer, time, tomorrow: false, inMinutes: toMinutes(time) - now };
        }
    }

    if (tomorrow) {
        const time = tomorrow.times.fajr;

        return {
            prayer: 'fajr',
            time,
            tomorrow: true,
            inMinutes: 1440 - now + toMinutes(time),
        };
    }

    return null;
}

/** The prayer whose time has come and not yet passed (null before Fajr). */
export function currentPrayer(
    today: DayTimes | null,
    timeZone: string,
    at: Date = new Date(),
): PrayerName | null {
    if (!today) {
        return null;
    }

    const now = minutesInZone(timeZone, at);
    let current: PrayerName | null = null;

    for (const prayer of COUNTED) {
        if (toMinutes(today.times[prayer]) <= now) {
            current = prayer;
        }
    }

    return current === 'shuruq' ? null : current;
}

/** 95.5 → "1:35:30" (h:mm:ss) or "35:30" under an hour. */
export function formatCountdown(minutes: number): string {
    const total = Math.max(0, Math.floor(minutes * 60));
    const h = Math.floor(total / 3600);
    const m = Math.floor((total % 3600) / 60);
    const s = total % 60;
    const pad = (n: number) => String(n).padStart(2, '0');

    return h > 0 ? `${h}:${pad(m)}:${pad(s)}` : `${m}:${pad(s)}`;
}
