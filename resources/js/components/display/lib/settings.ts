import type { DisplaySettings, Ranges, ScreenPrayer } from '../types';
import {
    ADHAN_MODES,
    CLOCKS,
    LANGUAGES,
    ORIENTATIONS,
    ROTATION_SOURCES,
    SCREEN_PRAYERS,
    THEMES,
} from '../types';

/** Mirrors config/display.php `ranges`. */
export const RANGES: Ranges = {
    hijri_adjust: [-2, 2],
    approaching_minutes: [0, 30],
    adhan_minutes: [1, 10],
    iqama_seconds: [10, 180],
    blackout_minutes: [0, 90],
    after_adhkar_minutes: [1, 15],
    rotation_seconds: [8, 120],
    volume: [0, 100],
};

const ID = /^[A-Za-z0-9_.:-]{1,64}$/;
const COLOR = /^#[0-9a-fA-F]{6}$/;
const TIME = /^([01]\d|2[0-3]):[0-5]\d$/;

const oneOf =
    <T extends string>(list: readonly T[]) =>
    (value: unknown): value is T =>
        typeof value === 'string' &&
        (list as readonly string[]).includes(value);

const inRange = (value: unknown, [min, max]: [number, number]) =>
    typeof value === 'number' &&
    Number.isInteger(value) &&
    value >= min &&
    value <= max;

function subset<T extends string>(
    value: unknown,
    list: readonly T[],
    min: number,
    max: number,
): T[] | undefined {
    if (!Array.isArray(value)) {
        return undefined;
    }

    const items = [...new Set(value.filter(oneOf(list)))];

    return items.length >= min && items.length <= max ? items : undefined;
}

/**
 * Only known keys with valid values (the same rules as
 * App\Services\Display\DisplaySettings::sanitize): guests' settings come
 * from localStorage, which anything may have written.
 */
export function sanitizeSettings(raw: unknown): Partial<DisplaySettings> {
    if (!raw || typeof raw !== 'object' || Array.isArray(raw)) {
        return {};
    }

    const input = raw as Record<string, unknown>;
    const out: Partial<DisplaySettings> = {};
    const set = <K extends keyof DisplaySettings>(
        key: K,
        value: DisplaySettings[K] | undefined,
    ) => {
        if (value !== undefined) {
            out[key] = value;
        }
    };

    set('theme', oneOf(THEMES)(input.theme) ? input.theme : undefined);
    set(
        'orientation',
        oneOf(ORIENTATIONS)(input.orientation) ? input.orientation : undefined,
    );
    set('clock', oneOf(CLOCKS)(input.clock) ? input.clock : undefined);
    set(
        'adhan_mode',
        oneOf(ADHAN_MODES)(input.adhan_mode) ? input.adhan_mode : undefined,
    );

    if (input.accent_color === null) {
        set('accent_color', null);
    } else if (
        typeof input.accent_color === 'string' &&
        COLOR.test(input.accent_color)
    ) {
        set('accent_color', input.accent_color.toLowerCase());
    }

    for (const key of ['adhan_id', 'fajr_adhan_id'] as const) {
        const value = input[key];

        if (value === null || (typeof value === 'string' && ID.test(value))) {
            set(key, value);
        }
    }

    for (const key of ['night_from', 'night_to'] as const) {
        const value = input[key];
        set(
            key,
            typeof value === 'string' && TIME.test(value) ? value : undefined,
        );
    }

    set('languages', subset(input.languages, LANGUAGES, 1, 2));
    set('rotation', subset(input.rotation, ROTATION_SOURCES, 0, 5));

    for (const key of [
        'show_seconds',
        'show_iqama',
        'show_shuruq',
        'show_jumua',
        'show_hijri',
        'after_adhkar',
        'muted',
        'night_dim',
    ] as const) {
        set(key, typeof input[key] === 'boolean' ? input[key] : undefined);
    }

    for (const key of [
        'hijri_adjust',
        'approaching_minutes',
        'adhan_minutes',
        'iqama_seconds',
        'after_adhkar_minutes',
        'rotation_seconds',
        'volume',
    ] as const) {
        set(
            key,
            inRange(input[key], RANGES[key])
                ? (input[key] as number)
                : undefined,
        );
    }

    const blackout = input.blackout_minutes;

    if (blackout && typeof blackout === 'object' && !Array.isArray(blackout)) {
        const clean: Partial<Record<ScreenPrayer, number>> = {};

        for (const prayer of SCREEN_PRAYERS) {
            const value = (blackout as Record<string, unknown>)[prayer];

            if (inRange(value, RANGES.blackout_minutes)) {
                clean[prayer] = value as number;
            }
        }

        out.blackout_minutes = clean as Record<ScreenPrayer, number>;
    }

    return out;
}

/** The defaults with valid choices over them (blackout minutes merge per prayer). */
export function mergeSettings(
    base: DisplaySettings,
    raw: unknown,
): DisplaySettings {
    const clean = sanitizeSettings(raw);

    return {
        ...base,
        ...clean,
        blackout_minutes: {
            ...base.blackout_minutes,
            ...clean.blackout_minutes,
        },
    };
}

/** Where a guest's personal screen settings live in this browser. */
export const PERSONAL_STORAGE_KEY = 'salat-time:display-settings';

export function readGuestSettings(): unknown {
    try {
        const raw = window.localStorage.getItem(PERSONAL_STORAGE_KEY);

        return raw ? JSON.parse(raw) : null;
    } catch {
        return null;
    }
}

export function writeGuestSettings(settings: DisplaySettings): void {
    try {
        window.localStorage.setItem(
            PERSONAL_STORAGE_KEY,
            JSON.stringify(sanitizeSettings(settings)),
        );
    } catch {
        // Private browsing or a full storage: the screen still works.
    }
}
