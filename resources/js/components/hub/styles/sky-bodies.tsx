import { useId } from 'react';
import { stars as makeStars } from '../sky';

/** The theme's gold (--gold) as a plain colour: SVG attributes do not resolve CSS variables everywhere. */
export const GOLD = 'rgb(224 187 94)';

/**
 * Sun, moon and stars drawn in SVG for the sky views, after the Mac app's
 * living sky. Animations are CSS only and stop under prefers-reduced-motion.
 */
export function SkyStyles() {
    return (
        <style>{`
.hub-twinkle { animation: hub-twinkle 4.5s ease-in-out infinite; }
.hub-glow { animation: hub-glow 5s ease-in-out infinite; transform-box: fill-box; transform-origin: center; }
.hub-rays { animation: hub-rays 80s linear infinite; transform-box: fill-box; transform-origin: center; }
.hub-draw { stroke-dasharray: 1; stroke-dashoffset: 1; animation: hub-draw 1.8s ease-out 0.15s forwards; }
@keyframes hub-twinkle { 0%, 100% { opacity: 1; } 50% { opacity: 0.35; } }
@keyframes hub-glow { 0%, 100% { transform: scale(1); } 50% { transform: scale(1.08); } }
@keyframes hub-rays { to { transform: rotate(360deg); } }
@keyframes hub-draw { to { stroke-dashoffset: 0; } }
@media (prefers-reduced-motion: reduce) {
  .hub-twinkle, .hub-glow, .hub-rays { animation: none; }
  .hub-draw { animation: none; stroke-dashoffset: 0; }
}`}</style>
    );
}

/** Stars over a rectangle, fading in as the sky darkens. */
export function SvgStars({
    x,
    y,
    width,
    height,
    count,
    seed,
    opacity,
    scale = 1,
}: {
    x: number;
    y: number;
    width: number;
    height: number;
    count: number;
    seed: number;
    opacity: number;
    /** Star size factor. */
    scale?: number;
}) {
    if (opacity < 0.05) {
        return null;
    }

    return (
        <g opacity={opacity} aria-hidden>
            {makeStars(count, seed).map((star, i) => (
                <circle
                    key={i}
                    cx={x + star.x * width}
                    cy={y + star.y * height}
                    r={star.r * scale}
                    fill="white"
                    className="hub-twinkle"
                    style={{ animationDelay: `${star.delay}s` }}
                />
            ))}
        </g>
    );
}

export function SvgSun({ cx, cy, r }: { cx: number; cy: number; r: number }) {
    const id = useId().replace(/:/g, '');

    return (
        <g aria-hidden>
            <defs>
                <radialGradient id={`${id}-glow`}>
                    <stop
                        offset="0%"
                        stopColor="rgb(255 219 133)"
                        stopOpacity="0.6"
                    />
                    <stop
                        offset="45%"
                        stopColor="rgb(255 184 77)"
                        stopOpacity="0.2"
                    />
                    <stop
                        offset="100%"
                        stopColor="rgb(255 179 77)"
                        stopOpacity="0"
                    />
                </radialGradient>
                <radialGradient id={`${id}-core`} cx="35%" cy="35%">
                    <stop offset="0%" stopColor="rgb(255 250 224)" />
                    <stop offset="100%" stopColor="rgb(255 204 97)" />
                </radialGradient>
            </defs>
            <circle
                cx={cx}
                cy={cy}
                r={r * 3.2}
                fill={`url(#${id}-glow)`}
                className="hub-glow"
            />
            <g className="hub-rays">
                {Array.from({ length: 14 }, (_, i) => {
                    const angle = (i * 2 * Math.PI) / 14;
                    const long = i % 2 === 0;
                    const inner = r * 1.35;
                    const outer = r * (long ? 2.1 : 1.7);

                    return (
                        <line
                            key={i}
                            x1={cx + Math.cos(angle) * inner}
                            y1={cy + Math.sin(angle) * inner}
                            x2={cx + Math.cos(angle) * outer}
                            y2={cy + Math.sin(angle) * outer}
                            stroke="rgb(255 217 128)"
                            strokeOpacity={long ? 0.55 : 0.35}
                            strokeWidth={long ? 1.6 : 1.1}
                            strokeLinecap="round"
                        />
                    );
                })}
            </g>
            <circle cx={cx} cy={cy} r={r} fill={`url(#${id}-core)`} />
        </g>
    );
}

const SYNODIC_MONTH = 29.530588853;
/** 2000-01-06 18:14 UTC, a new moon. */
const NEW_MOON_REFERENCE = 947_182_440;

/** Fraction of the lunar month (0 = new, 0.5 = full), from the mean synodic month. */
export function moonFraction(at: Date): number {
    const days = (at.getTime() / 1000 - NEW_MOON_REFERENCE) / 86_400;
    const age = ((days % SYNODIC_MONTH) + SYNODIC_MONTH) % SYNODIC_MONTH;

    return age / SYNODIC_MONTH;
}

/** The moon in its real phase: halo, dark disc and the lit part bounded by the terminator. */
export function SvgMoon({
    cx,
    cy,
    r,
    at,
    southern = false,
}: {
    cx: number;
    cy: number;
    r: number;
    at: Date;
    southern?: boolean;
}) {
    const fraction = moonFraction(at);
    const illumination = (1 - Math.cos(2 * Math.PI * fraction)) / 2;
    let litRight = fraction < 0.5;

    if (southern) {
        litRight = !litRight;
    }

    const k = Math.cos(2 * Math.PI * fraction);
    const rx = Math.abs(k) * r;
    const limbSweep = litRight ? 1 : 0;
    const terminatorSweep = k > 0 === litRight ? 0 : 1;
    const lit = `M ${cx} ${cy - r} A ${r} ${r} 0 0 ${limbSweep} ${cx} ${cy + r} A ${rx} ${r} 0 0 ${terminatorSweep} ${cx} ${cy - r} Z`;

    return (
        <g aria-hidden>
            <circle
                cx={cx}
                cy={cy}
                r={r * 2.4}
                fill="white"
                opacity={0.06 + 0.1 * illumination}
                className="hub-glow"
            />
            <circle cx={cx} cy={cy} r={r} fill="rgb(51 56 82)" opacity={0.8} />
            <path d={lit} fill="rgb(244 240 222)" />
        </g>
    );
}
