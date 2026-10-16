import { usePage } from '@inertiajs/react';
import { useEffect, useId, useRef, useState } from 'react';
import { useNow } from '@/hooks/use-now';
import { useT } from '@/lib/i18n';
import { minutesInZone, nextPrayer, toMinutes } from '@/lib/prayer-time';
import { cn } from '@/lib/utils';
import type { DayTimes } from '@/types/mosque';
import { PRAYERS } from '@/types/mosque';
import { skyStops, stars } from './day-path-sky';

const HEIGHT = 210;
const HORIZON = 150;
const ARC = 112;
const NIGHT_DEPTH = 40;
const PAD = 18;

type Props = { today: DayTimes; tomorrow: DayTimes | null; timezone: string };

/**
 * The day as the sky lives it, from Fajr to Isha: the sun's arc above the
 * horizon, twilight below it, each prayer on the path and the sun (or the
 * moon) at the mosque's current time. Animations respect reduced motion.
 */
export function DayPath({ today, tomorrow, timezone }: Props) {
    const t = useT();
    const { dir } = usePage().props;
    const id = useId().replace(/[^a-zA-Z0-9_-]/g, '');
    const now = useNow(30_000);
    const box = useRef<HTMLDivElement>(null);
    const [width, setWidth] = useState(720);

    useEffect(() => {
        const element = box.current;

        if (!element || typeof ResizeObserver === 'undefined') {
            return;
        }

        const observer = new ResizeObserver(([entry]) =>
            setWidth(Math.max(280, entry.contentRect.width)),
        );
        observer.observe(element);

        return () => observer.disconnect();
    }, []);

    const m = Object.fromEntries(
        PRAYERS.map((p) => [p, toMinutes(today.times[p])]),
    ) as Record<(typeof PRAYERS)[number], number>;

    // Far-north summers: Isha after midnight belongs to the same evening.
    if (m.isha < m.maghrib) {
        m.isha += 1440;
    }

    const start = m.fajr - 45;
    const end = m.isha + 45;
    const rise = m.shuruq;
    const set = m.maghrib;
    const fraction = (minute: number) => (minute - start) / (end - start);
    const x = (minute: number) => {
        const px = PAD + fraction(minute) * (width - PAD * 2);

        return dir === 'rtl' ? width - px : px;
    };
    const y = (minute: number) => {
        if (minute >= rise && minute <= set) {
            return (
                HORIZON -
                Math.sin(
                    ((minute - rise) / Math.max(1, set - rise)) * Math.PI,
                ) *
                    ARC
            );
        }

        const distance = minute < rise ? rise - minute : minute - set;
        const night = Math.max(1, 1440 - (set - rise));

        return (
            HORIZON +
            Math.sin(Math.min(1, (distance / night) * 2.2) * (Math.PI / 2)) *
                NIGHT_DEPTH
        );
    };
    const path = (from: number, to: number) => {
        const points: string[] = [];

        for (let minute = from; minute <= to; minute += 4) {
            points.push(`${x(minute).toFixed(1)},${y(minute).toFixed(1)}`);
        }

        points.push(`${x(to).toFixed(1)},${y(to).toFixed(1)}`);

        return `M${points.join('L')}`;
    };

    const nowMinute = minutesInZone(timezone, now);
    const inRange = nowMinute >= start && nowMinute <= end;
    const sunUp = nowMinute >= rise && nowMinute <= set;
    const next = nextPrayer(today, tomorrow, timezone, now);
    const nextKey = next && !next.tomorrow ? next.prayer : null;
    const stops = skyStops(m, start, end, dir === 'rtl');

    return (
        <figure className="space-y-2">
            <div
                ref={box}
                className="relative overflow-hidden rounded-2xl border bg-[oklch(0.22_0.04_250)]"
            >
                <svg
                    viewBox={`0 0 ${width} ${HEIGHT}`}
                    width="100%"
                    height={HEIGHT}
                    role="img"
                    aria-label={t('mosque.day_path_label')}
                    className="block"
                >
                    <style>{`
                        @media (prefers-reduced-motion: no-preference) {
                            .dp-draw-${id} { stroke-dasharray: 1; animation: dp-draw-${id} 1.8s ease-out both; }
                            .dp-glow-${id} { animation: dp-glow-${id} 3.2s ease-in-out infinite; transform-origin: center; transform-box: fill-box; }
                            .dp-star-${id} { animation: dp-twinkle-${id} 3.6s ease-in-out infinite; }
                        }
                        @keyframes dp-draw-${id} { from { stroke-dashoffset: 1; } to { stroke-dashoffset: 0; } }
                        @keyframes dp-glow-${id} { 0%, 100% { opacity: .55; transform: scale(1); } 50% { opacity: .9; transform: scale(1.12); } }
                        @keyframes dp-twinkle-${id} { 0%, 100% { opacity: .9; } 50% { opacity: .25; } }
                    `}</style>
                    <defs>
                        <linearGradient
                            id={`${id}-sky`}
                            x1="0"
                            x2="1"
                            y1="0"
                            y2="0"
                        >
                            {stops.map((stop, index) => (
                                <stop
                                    key={index}
                                    offset={stop.offset}
                                    stopColor={stop.color}
                                />
                            ))}
                        </linearGradient>
                        <linearGradient
                            id={`${id}-veil`}
                            x1="0"
                            x2="0"
                            y1="0"
                            y2="1"
                        >
                            <stop
                                offset="0"
                                stopColor="black"
                                stopOpacity="0.28"
                            />
                            <stop
                                offset="1"
                                stopColor="black"
                                stopOpacity="0"
                            />
                        </linearGradient>
                        <radialGradient id={`${id}-sun`}>
                            <stop
                                offset="0"
                                stopColor="oklch(0.92 0.13 85)"
                                stopOpacity="0.95"
                            />
                            <stop
                                offset="1"
                                stopColor="oklch(0.92 0.13 85)"
                                stopOpacity="0"
                            />
                        </radialGradient>
                    </defs>

                    <rect
                        width={width}
                        height={HORIZON}
                        fill={`url(#${id}-sky)`}
                    />
                    <rect
                        width={width}
                        height={HORIZON}
                        fill={`url(#${id}-veil)`}
                    />
                    {stars(width, HORIZON, (px) => {
                        const minute =
                            start +
                            (((dir === 'rtl' ? width - px : px) - PAD) /
                                (width - PAD * 2)) *
                                (end - start);

                        return minute < rise - 20 || minute > set + 25;
                    }).map((star, i) => (
                        <circle
                            key={i}
                            cx={star.x}
                            cy={star.y}
                            r={star.r}
                            fill="white"
                            className={`dp-star-${id}`}
                            style={{ animationDelay: `${star.delay}s` }}
                        />
                    ))}
                    <rect
                        y={HORIZON}
                        width={width}
                        height={HEIGHT - HORIZON}
                        fill="oklch(0.27 0.045 175)"
                    />
                    <line
                        x1="0"
                        x2={width}
                        y1={HORIZON}
                        y2={HORIZON}
                        stroke="white"
                        strokeOpacity="0.35"
                    />

                    <path
                        d={path(start, rise)}
                        fill="none"
                        stroke="white"
                        strokeOpacity="0.55"
                        strokeWidth="1.6"
                        strokeDasharray="4 5"
                    />
                    <path
                        d={path(set, end)}
                        fill="none"
                        stroke="white"
                        strokeOpacity="0.55"
                        strokeWidth="1.6"
                        strokeDasharray="4 5"
                    />
                    <path
                        d={path(rise, set)}
                        fill="none"
                        stroke="oklch(0.9 0.12 85)"
                        strokeOpacity="0.3"
                        strokeWidth="8"
                        strokeLinecap="round"
                        pathLength={1}
                        className={`dp-draw-${id}`}
                    />
                    <path
                        d={path(rise, set)}
                        fill="none"
                        stroke="white"
                        strokeOpacity="0.95"
                        strokeWidth="2.6"
                        strokeLinecap="round"
                        pathLength={1}
                        className={`dp-draw-${id}`}
                    />

                    {PRAYERS.map((prayer) => (
                        <circle
                            key={prayer}
                            cx={x(m[prayer])}
                            cy={y(m[prayer])}
                            r={prayer === nextKey ? 6.5 : 4.5}
                            fill={
                                prayer === nextKey
                                    ? 'oklch(0.84 0.12 85)'
                                    : 'white'
                            }
                            stroke="oklch(0.25 0.04 200)"
                            strokeWidth="1.5"
                        />
                    ))}

                    {inRange && sunUp && (
                        <g>
                            <circle
                                cx={x(nowMinute)}
                                cy={y(nowMinute)}
                                r="26"
                                fill={`url(#${id}-sun)`}
                                className={`dp-glow-${id}`}
                            />
                            <circle
                                cx={x(nowMinute)}
                                cy={y(nowMinute)}
                                r="10"
                                fill="oklch(0.9 0.14 88)"
                                stroke="white"
                                strokeWidth="1.5"
                            />
                        </g>
                    )}
                    {inRange && !sunUp && (
                        <Moon cx={x(nowMinute)} cy={y(nowMinute)} />
                    )}
                    {!inRange && (
                        <Moon cx={dir === 'rtl' ? 34 : width - 34} cy={34} />
                    )}
                </svg>
            </div>

            <figcaption className="relative h-12 text-[11px] sm:text-xs">
                {PRAYERS.map((prayer, index) => {
                    const left = Math.min(
                        94,
                        Math.max(6, (x(m[prayer]) / width) * 100),
                    );

                    return (
                        <span
                            key={prayer}
                            className={cn(
                                'absolute flex -translate-x-1/2 flex-col items-center leading-tight whitespace-nowrap',
                                index % 2 === 0 ? 'top-0' : 'top-6',
                                prayer === nextKey
                                    ? 'font-semibold text-foreground'
                                    : 'text-muted-foreground',
                            )}
                            style={{ left: `${left}%` }}
                        >
                            <span>{t(`site.prayer_${prayer}`)}</span>
                            <span dir="ltr" className="tabular-nums">
                                {today.times[prayer]}
                            </span>
                        </span>
                    );
                })}
            </figcaption>
        </figure>
    );
}

function Moon({ cx, cy }: { cx: number; cy: number }) {
    return (
        <g transform={`translate(${cx - 11} ${cy - 11})`}>
            <path
                d="M15.5 2.5a9.5 9.5 0 1 0 5 12.6A8 8 0 1 1 15.5 2.5Z"
                fill="oklch(0.95 0.03 95)"
                stroke="white"
                strokeOpacity="0.6"
            />
        </g>
    );
}
