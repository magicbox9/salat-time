/**
 * The living sky (after the Mac app's LivingSky): the colours of the sky at a
 * minute of the mosque's day, keyed on its own Fajr, sunrise, Maghrib and
 * Isha, blended with a smooth step; and where the sun or the moon stands on
 * its arc. Only colours and ideas are borrowed.
 */
type Rgb = [number, number, number];
type Pair = { top: Rgb; horizon: Rgb };

const NIGHT: Pair = { top: [0.035, 0.05, 0.14], horizon: [0.09, 0.11, 0.24] };
const DAWN: Pair = { top: [0.13, 0.17, 0.36], horizon: [0.72, 0.42, 0.5] };
const SUNRISE: Pair = { top: [0.3, 0.5, 0.8], horizon: [0.98, 0.7, 0.42] };
const DAY: Pair = { top: [0.16, 0.47, 0.82], horizon: [0.62, 0.8, 0.96] };
const GOLDEN: Pair = { top: [0.28, 0.43, 0.74], horizon: [0.98, 0.74, 0.44] };
const SUNSET: Pair = { top: [0.22, 0.22, 0.48], horizon: [0.95, 0.47, 0.33] };
const DUSK: Pair = { top: [0.08, 0.1, 0.27], horizon: [0.42, 0.26, 0.44] };

export type SkyDay = {
    fajr: number;
    shuruq: number;
    maghrib: number;
    isha: number;
};

function frames(day: SkyDay): [number, Pair][] {
    const isha = Math.min(day.isha, 1420);
    const raw: [number, Pair][] = [
        [0, NIGHT],
        [day.fajr - 15, NIGHT],
        [(day.fajr + day.shuruq) / 2, DAWN],
        [day.shuruq, SUNRISE],
        [day.shuruq + 60, DAY],
        [day.maghrib - 75, DAY],
        [day.maghrib - 25, GOLDEN],
        [day.maghrib, SUNSET],
        [(day.maghrib + isha) / 2, DUSK],
        [isha + 15, NIGHT],
        [1440, NIGHT],
    ];

    return raw.filter((frame, i) => i === 0 || frame[0] > raw[i - 1][0]);
}

const mix = (a: Rgb, b: Rgb, t: number): Rgb => [
    a[0] + (b[0] - a[0]) * t,
    a[1] + (b[1] - a[1]) * t,
    a[2] + (b[2] - a[2]) * t,
];

export function skyAt(minute: number, day: SkyDay): Pair {
    const value = ((minute % 1440) + 1440) % 1440;
    const list = frames(day);

    for (let i = 1; i < list.length; i++) {
        if (value <= list[i][0]) {
            const [ma, a] = list[i - 1];
            const [mb, b] = list[i];
            const t = (value - ma) / Math.max(1, mb - ma);
            const eased = t * t * (3 - 2 * t);

            return {
                top: mix(a.top, b.top, eased),
                horizon: mix(a.horizon, b.horizon, eased),
            };
        }
    }

    return NIGHT;
}

/** 0 = full day, 1 = deep night. */
export function darkness(pair: Pair): number {
    const [r, g, b] = pair.top;
    const luminance = 0.2126 * r + 0.7152 * g + 0.0722 * b;

    return Math.max(0, Math.min(1, 1 - (luminance - 0.05) / 0.35));
}

export function rgb(color: Rgb, alpha = 1): string {
    const [r, g, b] = color.map((v) => Math.round(v * 255));

    return `rgb(${r} ${g} ${b} / ${alpha})`;
}

/** Where the sun (by day) or the moon (by night) stands on its arc, 0 → 1. */
export function bodyOnArc(
    minute: number,
    day: SkyDay,
): { body: 'sun' | 'moon'; fraction: number } {
    const rise = day.shuruq;
    const set = day.maghrib;

    if (minute >= rise && minute <= set) {
        return {
            body: 'sun',
            fraction: (minute - rise) / Math.max(1, set - rise),
        };
    }

    const night = 1440 - (set - rise);
    const since = minute > set ? minute - set : minute + 1440 - set;

    return { body: 'moon', fraction: Math.min(1, since / Math.max(1, night)) };
}

/** Age of the moon in its cycle, 0 → 1 (0 = new moon), from a known new moon. */
export function moonPhase(at: Date): number {
    const synodic = 29.530588853;
    const reference = Date.UTC(2000, 0, 6, 18, 14);
    const days = (at.getTime() - reference) / 86_400_000;

    return (((days / synodic) % 1) + 1) % 1;
}

/** Stable pseudo-random stars (the same sky on every render). */
export function stars(
    count: number,
    seed: number,
): { x: number; y: number; r: number; delay: number }[] {
    let state = seed * 9301 + 49297;
    const next = () => {
        state = (state * 9301 + 49297) % 233280;

        return state / 233280;
    };

    return Array.from({ length: count }, () => ({
        x: next(),
        y: next(),
        r: 0.5 + next() * 1.2,
        delay: next() * 4,
    }));
}
