/**
 * The living sky of the Mac app (LivingSky): the colours of the sky at a
 * minute of the mosque's day, keyed on its own Fajr, sunrise, Maghrib and
 * Isha, blended with a smooth step. Only colours are borrowed here.
 */

type Rgb = [number, number, number];
export type SkyPair = { top: Rgb; horizon: Rgb };

const NIGHT: SkyPair = {
    top: [0.035, 0.05, 0.14],
    horizon: [0.09, 0.11, 0.24],
};
const DAWN: SkyPair = { top: [0.13, 0.17, 0.36], horizon: [0.72, 0.42, 0.5] };
const SUNRISE: SkyPair = { top: [0.3, 0.5, 0.8], horizon: [0.98, 0.7, 0.42] };
const DAY: SkyPair = { top: [0.16, 0.47, 0.82], horizon: [0.62, 0.8, 0.96] };
const GOLDEN: SkyPair = {
    top: [0.28, 0.43, 0.74],
    horizon: [0.98, 0.74, 0.44],
};
const SUNSET: SkyPair = {
    top: [0.22, 0.22, 0.48],
    horizon: [0.95, 0.47, 0.33],
};
const DUSK: SkyPair = { top: [0.08, 0.1, 0.27], horizon: [0.42, 0.26, 0.44] };

export type SkyDay = {
    fajr: number;
    shuruq: number;
    maghrib: number;
    isha: number;
};

function keyframes(day: SkyDay): [number, SkyPair][] {
    const isha = Math.min(day.isha, 1420);
    const raw: [number, SkyPair][] = [
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
    const frames: [number, SkyPair][] = [];

    for (const frame of raw) {
        if (frame[0] > (frames.at(-1)?.[0] ?? -1)) {
            frames.push(frame);
        }
    }

    return frames;
}

function mix(a: Rgb, b: Rgb, t: number): Rgb {
    return [
        a[0] + (b[0] - a[0]) * t,
        a[1] + (b[1] - a[1]) * t,
        a[2] + (b[2] - a[2]) * t,
    ];
}

export function skyAt(minute: number, day: SkyDay): SkyPair {
    const value = ((minute % 1440) + 1440) % 1440;
    const frames = keyframes(day);

    for (let i = 1; i < frames.length; i++) {
        if (value <= frames[i][0]) {
            const [ma, a] = frames[i - 1];
            const [mb, b] = frames[i];
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

/** 0 = full day, 1 = night (from the brightness of the top of the sky). */
export function darkness(pair: SkyPair): number {
    const [r, g, b] = pair.top;
    const luminance = 0.2126 * r + 0.7152 * g + 0.0722 * b;

    return Math.max(0, Math.min(1, 1 - (luminance - 0.05) / 0.35));
}

export function css(rgb: Rgb, alpha = 1): string {
    const [r, g, b] = rgb.map((v) => Math.round(v * 255));

    return alpha === 1
        ? `rgb(${r} ${g} ${b})`
        : `rgb(${r} ${g} ${b} / ${alpha})`;
}

/** A blend of the two colours, as the Mac dial's ring. */
export function ringColor(pair: SkyPair): string {
    return css(mix(pair.horizon, pair.top, 0.45));
}

/** Stable pseudo-random stars (same sky on every render). */
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
        r: 0.4 + next() * 1.1,
        delay: next() * 4,
    }));
}
