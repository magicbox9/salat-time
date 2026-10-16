import type { SkyDay } from '../sky';
import { ringColor, skyAt } from '../sky';

/** Geometry of the 24-hour dial (SVG units). */
export const SIZE = 440;
export const C = SIZE / 2;
export const RING = 132;
export const RING_WIDTH = 18;
export const DISC = 96;
export const LABEL = 164;
const STEP = 15;

/**
 * Minute of the day → angle and point: midnight at the bottom, noon at the
 * top, clockwise (counter-clockwise in Arabic, as the Mac app).
 */
export function dialGeometry(rtl: boolean) {
    const angle = (minute: number) => {
        const f = (((minute % 1440) + 1440) % 1440) / 1440;

        return rtl
            ? Math.PI / 2 - f * 2 * Math.PI
            : Math.PI / 2 + f * 2 * Math.PI;
    };
    const at = (minute: number, radius: number) => ({
        x: C + Math.cos(angle(minute)) * radius,
        y: C + Math.sin(angle(minute)) * radius,
    });

    return { angle, at };
}

/** The ring painted with the sky's colour through the day, and the hour ticks. */
export function DialRing({ day, rtl }: { day: SkyDay; rtl: boolean }) {
    const { at } = dialGeometry(rtl);
    const segment = (from: number) => {
        const a = at(from, RING);
        const b = at(from + STEP + 0.6, RING);

        return `M ${a.x.toFixed(2)} ${a.y.toFixed(2)} A ${RING} ${RING} 0 0 ${rtl ? 0 : 1} ${b.x.toFixed(2)} ${b.y.toFixed(2)}`;
    };

    return (
        <g aria-hidden>
            {Array.from({ length: 1440 / STEP }, (_, i) => i * STEP).map(
                (minute) => (
                    <path
                        key={minute}
                        d={segment(minute)}
                        fill="none"
                        stroke={ringColor(skyAt(minute + STEP / 2, day))}
                        strokeWidth={RING_WIDTH}
                    />
                ),
            )}
            <circle
                cx={C}
                cy={C}
                r={RING - RING_WIDTH / 2}
                fill="none"
                stroke="white"
                strokeOpacity={0.12}
            />
            <circle
                cx={C}
                cy={C}
                r={RING + RING_WIDTH / 2}
                fill="none"
                stroke="white"
                strokeOpacity={0.12}
            />

            {Array.from({ length: 24 }, (_, hour) => {
                const major = hour % 3 === 0;
                const a = at(hour * 60, RING - RING_WIDTH / 2 - 3);
                const b = at(
                    hour * 60,
                    RING - RING_WIDTH / 2 - (major ? 10 : 6),
                );
                const label = at(hour * 60, RING - RING_WIDTH / 2 - 20);

                return (
                    <g key={hour}>
                        <line
                            x1={a.x}
                            y1={a.y}
                            x2={b.x}
                            y2={b.y}
                            stroke="white"
                            strokeOpacity={major ? 0.7 : 0.35}
                            strokeWidth={major ? 1.6 : 1}
                        />
                        {hour % 6 === 0 && (
                            <text
                                x={label.x}
                                y={label.y + 3.5}
                                textAnchor="middle"
                                fontSize={10}
                                fill="white"
                                fillOpacity={0.55}
                                direction="ltr"
                            >
                                {String(hour).padStart(2, '0')}
                            </text>
                        )}
                    </g>
                );
            })}
        </g>
    );
}
