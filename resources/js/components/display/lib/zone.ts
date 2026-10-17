import { intlLocale } from '@/lib/i18n';
import type { ClockStyle } from '../types';

const formatters = new Map<string, Intl.DateTimeFormat>();

function partsFormatter(timeZone: string): Intl.DateTimeFormat {
    let value = formatters.get(timeZone);

    if (!value) {
        value = new Intl.DateTimeFormat('en-US', {
            timeZone,
            hourCycle: 'h23',
            year: 'numeric',
            month: '2-digit',
            day: '2-digit',
            hour: '2-digit',
            minute: '2-digit',
            second: '2-digit',
            weekday: 'short',
        });
        formatters.set(timeZone, value);
    }

    return value;
}

const WEEKDAYS = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

export type ZoneNow = {
    /** "Y-m-d" in the mosque's time zone. */
    date: string;
    /** Minutes since the mosque's midnight, seconds as a fraction. */
    minutes: number;
    hour: number;
    minute: number;
    second: number;
    /** 0 = Sunday … 5 = Friday. */
    weekday: number;
};

/** The mosque's wall clock at an instant (the device's own zone does not matter). */
export function zoneNow(timeZone: string, at: Date): ZoneNow {
    let parts: Intl.DateTimeFormatPart[];

    try {
        parts = partsFormatter(timeZone).formatToParts(at);
    } catch {
        parts = partsFormatter('UTC').formatToParts(at);
    }

    const get = (type: string) =>
        parts.find((p) => p.type === type)?.value ?? '';
    const hour = Number(get('hour')) % 24;
    const minute = Number(get('minute'));
    const second = Number(get('second'));

    return {
        date: `${get('year')}-${get('month')}-${get('day')}`,
        minutes: hour * 60 + minute + second / 60,
        hour,
        minute,
        second,
        weekday: Math.max(0, WEEKDAYS.indexOf(get('weekday'))),
    };
}

/** The zone's offset from UTC at an instant, in minutes. */
function offsetAt(timeZone: string, at: number): number {
    const local = zoneNow(timeZone, new Date(at));
    const [y, m, d] = local.date.split('-').map(Number);
    const asUtc = Date.UTC(y, m - 1, d, local.hour, local.minute, local.second);

    return Math.round((asUtc - Math.floor(at / 1000) * 1000) / 60_000);
}

/**
 * Real minutes from `now` until a wall-clock time of the mosque (minutes
 * after the midnight of `date`, beyond 1440 for the next day). Unlike a
 * difference of wall-clock minutes, it stays right across a change to or
 * from summer time.
 */
export function minutesUntil(
    timeZone: string,
    now: Date,
    date: string,
    minutes: number,
): number {
    const [y, m, d] = date.split('-').map(Number);
    const wall = Date.UTC(y, m - 1, d) + Math.round(minutes * 60_000);
    let instant = wall - offsetAt(timeZone, wall) * 60_000;
    instant = wall - offsetAt(timeZone, instant) * 60_000;

    return (instant - now.getTime()) / 60_000;
}

/** "Y-m-d" plus n days. */
export function addDays(iso: string, days: number): string {
    const [y, m, d] = iso.split('-').map(Number);
    const date = new Date(Date.UTC(y, m - 1, d + days, 12));

    return date.toISOString().slice(0, 10);
}

function utcNoon(iso: string): Date {
    const [y, m, d] = iso.split('-').map(Number);

    return new Date(Date.UTC(y, m - 1, d, 12));
}

const pad = (n: number) => String(n).padStart(2, '0');

const dayPeriodCache = new Map<string, [string, string]>();

/** "AM" / "PM" in a language ("ص" / "م" in Arabic). */
function dayPeriods(language: string): [string, string] {
    let value = dayPeriodCache.get(language);

    if (!value) {
        const period = (hour: number, fallback: string) => {
            try {
                return (
                    new Intl.DateTimeFormat(intlLocale(language), {
                        hour: 'numeric',
                        hour12: true,
                        timeZone: 'UTC',
                    })
                        .formatToParts(new Date(Date.UTC(2020, 0, 1, hour)))
                        .find((part) => part.type === 'dayPeriod')?.value ??
                    fallback
                );
            } catch {
                return fallback;
            }
        };
        value = [period(9, 'AM'), period(15, 'PM')];
        dayPeriodCache.set(language, value);
    }

    return value;
}

/** The big clock: "13:05" + "42", or "1:05" + "42" + "PM" (in the screen's language). */
export function clockParts(
    now: ZoneNow,
    clock: ClockStyle,
    language = 'en',
): { main: string; seconds: string; suffix: string | null } {
    if (clock === '12h') {
        const hour = now.hour % 12 || 12;
        const [am, pm] = dayPeriods(language);

        return {
            main: `${hour}:${pad(now.minute)}`,
            seconds: pad(now.second),
            suffix: now.hour < 12 ? am : pm,
        };
    }

    return {
        main: `${pad(now.hour)}:${pad(now.minute)}`,
        seconds: pad(now.second),
        suffix: null,
    };
}

/** A published "HH:MM" in the chosen style ("13:05" or "1:05"). */
export function formatTime(hhmm: string, clock: ClockStyle): string {
    if (clock === '24h') {
        return hhmm;
    }

    const [h, m] = hhmm.split(':').map(Number);

    if (Number.isNaN(h) || Number.isNaN(m)) {
        return hhmm;
    }

    return `${h % 12 || 12}:${pad(m)}`;
}

export function gregorianDate(iso: string, language: string): string {
    try {
        return new Intl.DateTimeFormat(intlLocale(language), {
            weekday: 'long',
            day: 'numeric',
            month: 'long',
            year: 'numeric',
            timeZone: 'UTC',
        }).format(utcNoon(iso));
    } catch {
        return iso;
    }
}

/** Umm al-Qura, shifted by the mosque's adjustment (-2 … +2 days). */
export function hijriDate(
    iso: string,
    language: string,
    adjust: number,
): string {
    try {
        return new Intl.DateTimeFormat(intlLocale(language), {
            calendar: 'islamic-umalqura',
            numberingSystem: 'latn',
            day: 'numeric',
            month: 'long',
            year: 'numeric',
            timeZone: 'UTC',
        }).format(utcNoon(addDays(iso, adjust)));
    } catch {
        return '';
    }
}

/** Minutes → "1:05:09" / "5:09" (with seconds) or "1:05" (h:mm, rounded up). */
export function countdown(minutes: number, withSeconds = true): string {
    if (!withSeconds) {
        const total = Math.max(0, Math.ceil(minutes));

        return `${Math.floor(total / 60)}:${pad(total % 60)}`;
    }

    const total = Math.max(0, Math.ceil(minutes * 60 - 0.001));
    const h = Math.floor(total / 3600);
    const m = Math.floor((total % 3600) / 60);
    const s = total % 60;

    return h > 0 ? `${h}:${pad(m)}:${pad(s)}` : `${m}:${pad(s)}`;
}

/** "HH:MM" → minutes, or null. */
export function hhmm(value: string | null | undefined): number | null {
    const match = /^(\d{1,2}):(\d{2})$/.exec(value ?? '');

    if (!match) {
        return null;
    }

    const h = Number(match[1]);
    const m = Number(match[2]);

    return h < 48 && m < 60 ? h * 60 + m : null;
}

/** Arabic-Indic digits for ayah numbers ("٢٥٥"). */
export function arabicDigits(value: number): string {
    return new Intl.NumberFormat('ar-EG', { useGrouping: false }).format(value);
}
