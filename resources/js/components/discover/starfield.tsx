import type { CSSProperties } from 'react';

/** Tiny fixed stars (static decoration: no user content). */
const STARS = [
    [12, 18, 1],
    [27, 72, 1.5],
    [41, 33, 1],
    [55, 88, 1],
    [68, 12, 1.5],
    [83, 54, 1],
    [92, 27, 1],
    [6, 61, 1],
    [19, 91, 1],
    [34, 8, 1.5],
    [47, 64, 1],
    [61, 41, 1],
    [74, 79, 1.5],
    [88, 6, 1],
    [97, 71, 1],
    [3, 38, 1.5],
    [15, 49, 1],
    [30, 25, 1],
    [52, 17, 1],
    [79, 93, 1],
    [95, 44, 1.5],
] as const;

const layer = (shift: number): CSSProperties => ({
    backgroundImage: STARS.map(
        ([x, y, size]) =>
            `radial-gradient(${size}px ${size}px at ${(x + shift) % 100}% ${(y + shift * 1.7) % 100}%, rgba(255,255,255,0.9), transparent)`,
    ).join(','),
});

/**
 * The night sky around the globe: a deep teal-to-midnight gradient with two
 * layers of stars, one of them softly twinkling (still for reduced motion).
 */
export function Starfield() {
    return (
        <div
            aria-hidden
            className="pointer-events-none absolute inset-0 overflow-hidden"
        >
            <div className="absolute inset-0 bg-[radial-gradient(ellipse_at_50%_45%,oklch(0.27_0.05_195)_0%,oklch(0.16_0.035_215)_45%,oklch(0.09_0.02_250)_100%)]" />
            <div className="absolute inset-0 opacity-70" style={layer(0)} />
            <div
                className="absolute inset-0 opacity-50 motion-safe:animate-pulse"
                style={layer(37)}
            />
            <div className="absolute -inset-x-1/4 top-1/2 h-1/2 bg-[radial-gradient(ellipse_at_50%_100%,oklch(0.78_0.12_85/0.08),transparent_60%)]" />
        </div>
    );
}
