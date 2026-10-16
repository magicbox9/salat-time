import { intlLocale } from '@/lib/i18n';

/**
 * Calendar helpers. Dates are handled as "Y-m-d" strings (the mosque's local
 * calendar day) and turned into UTC noon instants only to ask Intl about them,
 * so no time zone can shift a day.
 */

const HIJRI = 'islamic-umalqura';

export function isoToUtcNoon(iso: string): Date {
    const [y, m, d] = iso.split('-').map(Number);

    return new Date(Date.UTC(y, m - 1, d, 12));
}

export function utcNoonToIso(date: Date): string {
    return date.toISOString().slice(0, 10);
}

export function addDays(iso: string, days: number): string {
    const date = isoToUtcNoon(iso);
    date.setUTCDate(date.getUTCDate() + days);

    return utcNoonToIso(date);
}

/** Today's "Y-m-d" in a time zone. */
export function todayIn(timeZone: string, at: Date = new Date()): string {
    return new Intl.DateTimeFormat('en-CA', {
        timeZone,
        year: 'numeric',
        month: '2-digit',
        day: '2-digit',
    }).format(at);
}

const hijriNumbers = new Intl.DateTimeFormat('en', {
    calendar: HIJRI,
    numberingSystem: 'latn',
    timeZone: 'UTC',
    day: 'numeric',
    month: 'numeric',
    year: 'numeric',
});

/** Hijri day / month / year of a "Y-m-d" date (Umm al-Qura, as the Mac app). */
export function hijriParts(iso: string): {
    day: number;
    month: number;
    year: number;
} {
    const parts = hijriNumbers.formatToParts(isoToUtcNoon(iso));
    const get = (type: string) =>
        Number(parts.find((p) => p.type === type)?.value ?? 0);

    return {
        day: get('day'),
        month: get('month'),
        year: get('year') || get('relatedYear'),
    };
}

/** First day and length of the Hijri month that contains `iso`. */
export function hijriMonthRange(iso: string): { start: string; days: number } {
    let start = iso;

    for (let i = 0; i < 31 && hijriParts(start).day !== 1; i++) {
        start = addDays(start, -1);
    }

    let days = 1;

    while (days < 31 && hijriParts(addDays(start, days)).day !== 1) {
        days++;
    }

    return { start, days };
}

/** First day and length of the Gregorian month that contains `iso`. */
export function gregorianMonthRange(iso: string): {
    start: string;
    days: number;
} {
    const [y, m] = iso.split('-').map(Number);
    const days = new Date(Date.UTC(y, m, 0)).getUTCDate();

    return { start: `${y}-${String(m).padStart(2, '0')}-01`, days };
}

export function formatHijri(
    iso: string,
    locale: string,
    options: Intl.DateTimeFormatOptions = {
        day: 'numeric',
        month: 'long',
        year: 'numeric',
    },
): string {
    return new Intl.DateTimeFormat(intlLocale(locale), {
        ...options,
        calendar: HIJRI,
        numberingSystem: 'latn',
        timeZone: 'UTC',
    }).format(isoToUtcNoon(iso));
}

export function formatGregorian(
    iso: string,
    locale: string,
    options: Intl.DateTimeFormatOptions = {
        weekday: 'long',
        day: 'numeric',
        month: 'long',
        year: 'numeric',
    },
): string {
    return new Intl.DateTimeFormat(intlLocale(locale), {
        ...options,
        timeZone: 'UTC',
    }).format(isoToUtcNoon(iso));
}

/** A date-time instant shown in the mosque's time zone. */
export function formatInstant(
    instant: string,
    locale: string,
    timeZone: string,
    options: Intl.DateTimeFormatOptions = { dateStyle: 'medium' },
): string {
    return new Intl.DateTimeFormat(intlLocale(locale), {
        ...options,
        timeZone,
    }).format(new Date(instant));
}

export function isFriday(iso: string): boolean {
    return isoToUtcNoon(iso).getUTCDay() === 5;
}
