import type { ScreenModel } from '../lib/model';
import type { ScreenText } from '../lib/text';
import type { ScreenPrayer } from '../types';
import { Lang, Time } from './parts';

/**
 * The adhan: light spreading in slow rings from a crescent over two slender
 * leaning minarets (the Mac app's silhouette), the prayer's name in Arabic
 * and in the screen's other language. The rings stand still for visitors
 * who ask for less motion.
 */
export function AdhanMoment({
    model,
    text,
    prayer,
}: {
    model: ScreenModel;
    text: ScreenText;
    prayer: ScreenPrayer;
}) {
    const other = text.translation;

    return (
        <div
            className="d-fade absolute inset-0 z-20 flex flex-col items-center justify-center overflow-hidden text-center"
            style={{
                background:
                    'radial-gradient(circle at 50% 42%, color-mix(in oklab, var(--d-accent) 26%, var(--d-bg)) 0%, color-mix(in oklab, var(--d-accent) 6%, var(--d-bg)) 38%, var(--d-bg) 72%)',
            }}
            role="status"
            aria-live="assertive"
        >
            <div
                className="pointer-events-none absolute top-[42%] left-1/2 -translate-x-1/2 -translate-y-1/2"
                aria-hidden
            >
                {[0, 1.5, 3].map((delay) => (
                    <span
                        key={delay}
                        className="d-ripple absolute top-1/2 left-1/2 -mt-[32cqmin] -ml-[32cqmin] size-[64cqmin] rounded-full border-[0.25cqmin] border-(--d-accent)"
                        style={{ animationDelay: `${delay}s`, opacity: 0.35 }}
                    />
                ))}
            </div>

            <Emblem />

            <p className="relative mt-[3cqmin] flex items-center gap-[1.6cqmin] text-[3cqmin] font-medium tracking-[0.25em] text-(--d-accent) uppercase">
                <Lang language="ar" className="tracking-normal">
                    {text.in('ar', 'adhan')}
                </Lang>
                {other && (
                    <>
                        <span className="opacity-50">·</span>
                        <Lang language={other}>{text.in(other, 'adhan')}</Lang>
                    </>
                )}
            </p>
            <p
                lang="ar"
                dir="rtl"
                className="d-fade-up relative mt-[1.4cqmin] font-arabic text-[17cqmin] leading-[1.15] font-bold"
            >
                {text.in('ar', `prayer_${prayer}`)}
            </p>
            {other && (
                <Lang
                    language={other}
                    className="d-fade-up relative mt-[1.2cqmin] text-[6cqmin] font-medium text-(--d-muted)"
                >
                    {text.in(other, `prayer_${prayer}`)}
                </Lang>
            )}
            <Time
                value={model.phase.event?.time ?? null}
                model={model}
                className="relative mt-[2.4cqmin] text-[4cqmin] text-(--d-muted)"
            />
        </div>
    );
}

function Emblem() {
    return (
        <svg
            viewBox="0 0 120 120"
            className="d-breathe relative size-[16cqmin]"
            aria-hidden
        >
            <defs>
                <linearGradient id="adhan-gold" x1="0" y1="0" x2="0" y2="1">
                    <stop offset="0" stopColor="var(--d-accent)" />
                    <stop
                        offset="1"
                        stopColor="color-mix(in oklab, var(--d-accent) 55%, white)"
                    />
                </linearGradient>
            </defs>
            {/* Crescent */}
            <path
                d="M70 14a26 26 0 1 0 22 44A21 21 0 1 1 70 14Z"
                fill="url(#adhan-gold)"
            />
            {/* Two slender leaning minarets and a folded hall */}
            <path
                d="M30 112 37 52l3-6 3 6-4 60Z"
                fill="url(#adhan-gold)"
                opacity="0.9"
            />
            <path
                d="M84 112 81 58l3-6 3 6 4 54Z"
                fill="url(#adhan-gold)"
                opacity="0.9"
            />
            <path
                d="M42 112 50 86l10-8 10 8 8 26Z"
                fill="url(#adhan-gold)"
                opacity="0.65"
            />
        </svg>
    );
}
