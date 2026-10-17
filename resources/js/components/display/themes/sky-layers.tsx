import { cn } from '@/lib/utils';
import type { ScreenModel } from '../lib/model';
import { bodyOnArc, darkness, moonPhase, rgb, skyAt, stars } from './sky';

const FALLBACK_DAY = { fajr: 330, shuruq: 450, maghrib: 1140, isha: 1230 };
const STARS = stars(90, 11);

/** The sky of this minute, its stars after dusk and a mosque on the horizon. */
export function SkyBackdrop({ model }: { model: ScreenModel }) {
    const day = model.sky ?? FALLBACK_DAY;
    const pair = skyAt(model.zone.minutes, day);
    const dark = darkness(pair);

    return (
        <div
            className="absolute inset-0 transition-[background] duration-[60s] ease-linear"
            style={{
                background: `linear-gradient(180deg, ${rgb(pair.top)} 0%, ${rgb(pair.horizon)} 100%)`,
            }}
            aria-hidden
        >
            <div
                className="absolute inset-x-0 top-0 h-[70%]"
                style={{ opacity: dark }}
            >
                {STARS.map((star, i) => (
                    <span
                        key={i}
                        className="d-twinkle absolute rounded-full bg-white"
                        style={{
                            left: `${star.x * 100}%`,
                            top: `${star.y * 100}%`,
                            width: `${star.r * 0.22}cqmin`,
                            height: `${star.r * 0.22}cqmin`,
                            animationDelay: `${star.delay}s`,
                        }}
                    />
                ))}
            </div>
            <svg
                viewBox="0 0 1000 160"
                preserveAspectRatio="xMidYMax slice"
                className="absolute inset-x-0 bottom-0 h-[18%] w-full"
            >
                <g fill="black" fillOpacity={0.16 + 0.18 * dark}>
                    <path d="M0 160V138Q180 122 370 136L380 160Z M620 160 630 136Q820 120 1000 134V160Z" />
                    <path d="M380 160 402 112 470 92 500 70 530 92 598 112 620 160Z" />
                    <path d="M298 160 323 38 330 26 337 38 321 160Z" />
                    <path d="M679 160 663 38 670 26 677 38 702 160Z" />
                </g>
            </svg>
        </div>
    );
}

/** A dashed arc with the sun (by day) or the moon in its phase (by night); morning on the leading side. */
export function SkyArc({
    model,
    rtl,
    southern,
    className,
}: {
    model: ScreenModel;
    rtl: boolean;
    southern: boolean;
    className?: string;
}) {
    const day = model.sky ?? FALLBACK_DAY;
    const { body, fraction } = bodyOnArc(model.zone.minutes, day);
    // On the arc's own curve (a quadratic Bézier from 60,190 over 500,-130 to 940,190).
    const t = rtl ? 1 - fraction : fraction;
    const x = (1 - t) ** 2 * 60 + 2 * (1 - t) * t * 500 + t ** 2 * 940;
    const y = (1 - t) ** 2 * 190 + 2 * (1 - t) * t * -130 + t ** 2 * 190;

    return (
        <svg
            viewBox="0 0 1000 200"
            preserveAspectRatio="xMidYMid meet"
            className={cn(
                'pointer-events-none absolute inset-x-[6%] w-[88%]',
                className,
            )}
            aria-hidden
        >
            <path
                d="M60 190 Q500 -130 940 190"
                fill="none"
                stroke="white"
                strokeOpacity={0.28}
                strokeWidth={1.6}
                strokeDasharray="3 9"
            />
            {body === 'sun' ? (
                <g>
                    <circle
                        cx={x}
                        cy={y}
                        r={34}
                        fill="#ffd27a"
                        fillOpacity={0.18}
                    />
                    <circle cx={x} cy={y} r={18} fill="#ffe3a3" />
                </g>
            ) : (
                <Moon
                    cx={x}
                    cy={y}
                    r={16}
                    phase={moonPhase(
                        new Date(
                            `${model.zone.date}T${String(model.zone.hour).padStart(2, '0')}:00:00Z`,
                        ),
                    )}
                    southern={southern}
                />
            )}
        </svg>
    );
}

function Moon({
    cx,
    cy,
    r,
    phase,
    southern,
}: {
    cx: number;
    cy: number;
    r: number;
    phase: number;
    southern: boolean;
}) {
    const waxing = phase < 0.5 !== southern;
    const k = Math.cos(2 * Math.PI * phase);
    const rx = Math.abs(k) * r;
    const limb = waxing ? 1 : 0;
    const terminator = waxing ? (k > 0 ? 0 : 1) : k > 0 ? 1 : 0;

    return (
        <g>
            <circle
                cx={cx}
                cy={cy}
                r={r * 2.2}
                fill="white"
                fillOpacity={0.06}
            />
            <circle cx={cx} cy={cy} r={r} fill="white" fillOpacity={0.12} />
            <path
                d={`M${cx} ${cy - r}A${r} ${r} 0 0 ${limb} ${cx} ${cy + r}A${rx} ${r} 0 0 ${terminator} ${cx} ${cy - r}Z`}
                fill="#f4f1e6"
            />
        </g>
    );
}
