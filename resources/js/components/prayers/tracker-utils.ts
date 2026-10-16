import { router } from '@inertiajs/react';
import { minutesInZone, toMinutes } from '@/lib/prayer-time';
import type { DayTimes } from '@/types/mosque';
import type { LogStatus, TrackedPrayer } from './types';

/** Colour of a status: cell fill and badge. */
export const STATUS_STYLE: Record<
    LogStatus,
    { cell: string; badge: string; dot: string }
> = {
    on_time: {
        cell: 'bg-primary border-primary',
        badge: 'bg-primary/12 text-primary border-primary/25',
        dot: 'bg-primary',
    },
    late: {
        cell: 'bg-amber-500 border-amber-500',
        badge: 'bg-amber-500/12 text-amber-700 border-amber-500/30 dark:text-amber-300',
        dot: 'bg-amber-500',
    },
    qada: {
        cell: 'bg-sky-600 border-sky-600 dark:bg-sky-500 dark:border-sky-500',
        badge: 'bg-sky-600/12 text-sky-700 border-sky-600/30 dark:text-sky-300',
        dot: 'bg-sky-600 dark:bg-sky-500',
    },
    missed: {
        cell: 'bg-rose-400/70 border-rose-400/70 dark:bg-rose-500/50 dark:border-rose-500/50',
        badge: 'bg-rose-500/10 text-rose-700 border-rose-500/25 dark:text-rose-300',
        dot: 'bg-rose-400',
    },
};

/** The event that ends each prayer's time (Fajr ends at sunrise, Isha at tomorrow's Fajr). */
const WINDOW_END: Record<TrackedPrayer, 'shuruq' | TrackedPrayer | null> = {
    fajr: 'shuruq',
    dhuhr: 'asr',
    asr: 'maghrib',
    maghrib: 'isha',
    isha: null,
};

export type PrayerWindow = 'upcoming' | 'current' | 'passed' | 'unknown';

/** Where today's prayer stands right now, from the mosque's published times. */
export function prayerWindow(
    prayer: TrackedPrayer,
    times: DayTimes | null | undefined,
    timeZone: string,
    now: Date,
): PrayerWindow {
    if (!times) {
        return 'unknown';
    }

    const minutes = minutesInZone(timeZone, now);
    const start = times.times[prayer];

    if (!start) {
        return 'unknown';
    }

    if (minutes < toMinutes(start)) {
        return 'upcoming';
    }

    const end = WINDOW_END[prayer];

    // Isha runs until tomorrow's Fajr: on today's date it never ends.
    if (end === null) {
        return 'current';
    }

    return minutes < toMinutes(times.times[end]) ? 'current' : 'passed';
}

/** The status we suggest for a check-in: on time inside the window, late after it. */
export function suggestStatus(window: PrayerWindow): LogStatus {
    return window === 'passed' ? 'late' : 'on_time';
}

/** The browser's IANA time zone (sent so "today" is right without an own mosque). */
export function deviceTimezone(): string | undefined {
    try {
        return Intl.DateTimeFormat().resolvedOptions().timeZone || undefined;
    } catch {
        return undefined;
    }
}

/** The calendar day ("2026-10-16") of an instant in a time zone. */
export function dateInZone(timeZone: string, at: Date = new Date()): string {
    const parts = new Intl.DateTimeFormat('en-GB', {
        timeZone,
        year: 'numeric',
        month: '2-digit',
        day: '2-digit',
    }).formatToParts(at);
    const get = (type: string) =>
        parts.find((part) => part.type === type)?.value ?? '';

    return `${get('year')}-${get('month')}-${get('day')}`;
}

/** The first validation message of a failed visit, if any. */
export function firstError(errors: Record<string, string>): string | undefined {
    return Object.values(errors)[0];
}

/** Undo a check-in. */
export function removeLog(id: number, onFinish?: () => void): void {
    router.delete(`/prayers/logs/${id}`, {
        data: { tz: deviceTimezone() },
        preserveScroll: true,
        onFinish,
    });
}

/** "2026-10-16" → a short localized date (no time-zone shift). */
export function formatDay(
    date: string,
    locale: string,
    options: Intl.DateTimeFormatOptions = {
        weekday: 'short',
        day: 'numeric',
        month: 'short',
    },
): string {
    const [y, m, d] = date.split('-').map(Number);

    return new Intl.DateTimeFormat(locale, {
        ...options,
        timeZone: 'UTC',
    }).format(new Date(Date.UTC(y, m - 1, d)));
}

/** Hasanat numbers: gold, darkened in light mode so they stay readable. */
export const HASANAT_TEXT = 'text-amber-700 dark:text-gold';
