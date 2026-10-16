import { intlLocale } from '@/lib/i18n';
import { formatCountdown } from '@/lib/prayer-time';
import type { HubPrefs } from './types';

/** "Y-m-d" → a Date at noon UTC, so no time zone can shift the day. */
function utcNoon(iso: string): Date {
    const [y, m, d] = iso.split('-').map(Number);

    return new Date(Date.UTC(y, m - 1, d, 12));
}

/** "13:05" in the chosen 24 h / 12 h style ("1:05 PM", "1:05 م"). */
export function formatClock(
    hhmm: string,
    clock: HubPrefs['clock'],
    locale: string,
): string {
    if (clock === '24h') {
        return hhmm;
    }

    const [h, m] = hhmm.split(':').map(Number);

    if (Number.isNaN(h) || Number.isNaN(m)) {
        return hhmm;
    }

    return new Intl.DateTimeFormat(intlLocale(locale), {
        hour: 'numeric',
        minute: '2-digit',
        hour12: true,
        timeZone: 'UTC',
    }).format(new Date(Date.UTC(2000, 0, 1, h % 24, m)));
}

/** The current time in the mosque's time zone, in the chosen style. */
export function formatNow(
    now: Date,
    timeZone: string,
    prefs: Pick<HubPrefs, 'clock' | 'show_seconds'>,
    locale: string,
): string {
    try {
        return new Intl.DateTimeFormat(
            prefs.clock === '12h' ? intlLocale(locale) : 'en-GB',
            {
                timeZone,
                hour: prefs.clock === '12h' ? 'numeric' : '2-digit',
                minute: '2-digit',
                second: prefs.show_seconds ? '2-digit' : undefined,
                hourCycle: prefs.clock === '12h' ? 'h12' : 'h23',
            },
        ).format(now);
    } catch {
        return '';
    }
}

/** 95.5 → "1:35:30" with seconds, "1:36" without (rounded up to the minute). */
export function formatLeft(minutes: number, seconds: boolean): string {
    if (seconds) {
        return formatCountdown(minutes);
    }

    const total = Math.max(0, Math.ceil(minutes));
    const h = Math.floor(total / 60);
    const m = total % 60;

    return `${h}:${String(m).padStart(2, '0')}`;
}

export function formatGregorianDate(iso: string, locale: string): string {
    return new Intl.DateTimeFormat(intlLocale(locale), {
        weekday: 'long',
        day: 'numeric',
        month: 'long',
        year: 'numeric',
        timeZone: 'UTC',
    }).format(utcNoon(iso));
}

/** Umm al-Qura, as the Mac app. */
export function formatHijriDate(iso: string, locale: string): string {
    try {
        return new Intl.DateTimeFormat(intlLocale(locale), {
            calendar: 'islamic-umalqura',
            numberingSystem: 'latn',
            day: 'numeric',
            month: 'long',
            year: 'numeric',
            timeZone: 'UTC',
        }).format(utcNoon(iso));
    } catch {
        return '';
    }
}

export function formatPostDate(instant: string, locale: string): string {
    return new Intl.DateTimeFormat(intlLocale(locale), {
        day: 'numeric',
        month: 'short',
        year: 'numeric',
    }).format(new Date(instant));
}

/** The visitor's own time zone (null when the browser hides it). */
export function deviceTimezone(): string | null {
    try {
        return Intl.DateTimeFormat().resolvedOptions().timeZone || null;
    } catch {
        return null;
    }
}
