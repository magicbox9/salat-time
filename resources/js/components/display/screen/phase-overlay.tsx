import { BellOff } from 'lucide-react';
import { cn } from '@/lib/utils';
import type { ScreenModel } from '../lib/model';
import type { ScreenText } from '../lib/text';
import { countdown } from '../lib/zone';
import type { AfterPrayerDhikr, ScreenPrayer } from '../types';
import { AdhanMoment } from './adhan-moment';
import { AfterPrayer } from './after-prayer';
import { Layer } from './layer';
import { BigClock, Lang, Ltr, Time } from './parts';

type Props = {
    model: ScreenModel;
    text: ScreenText;
    afterPrayer: AfterPrayerDhikr[];
};

/**
 * The full-screen moments of a prayer, over every theme: the adhan, the
 * countdown to the iqama, the iqama itself, the dimmed screen while the
 * prayer is in progress and the adhkar after it.
 */
export function PhaseOverlay({ model, text, afterPrayer }: Props) {
    const { phase } = model;
    const prayer = phase.event?.prayer ?? null;

    if (!prayer || phase.kind === 'normal' || phase.kind === 'approaching') {
        return null;
    }

    switch (phase.kind) {
        case 'adhan':
            return <AdhanMoment model={model} text={text} prayer={prayer} />;
        case 'iqama_countdown':
            return <IqamaCountdown model={model} text={text} prayer={prayer} />;
        case 'iqama':
            return <IqamaMoment text={text} />;
        case 'prayer':
            return <PrayerDim model={model} text={text} prayer={prayer} />;
        case 'after_adhkar':
            return afterPrayer.length > 0 ? (
                <AfterPrayer model={model} text={text} items={afterPrayer} />
            ) : null;
    }
}

function IqamaCountdown({
    model,
    text,
    prayer,
}: {
    model: ScreenModel;
    text: ScreenText;
    prayer: ScreenPrayer;
}) {
    const name = text.prayer(prayer);
    const radius = 46;
    const circumference = 2 * Math.PI * radius;
    const left = model.phase.remaining;

    return (
        <Layer
            style={{
                background:
                    'radial-gradient(circle at 50% 40%, color-mix(in oklab, var(--d-accent) 12%, var(--d-bg)) 0%, var(--d-bg) 70%)',
            }}
        >
            <Lang
                language={text.primary}
                className="text-[6cqmin] leading-tight font-semibold text-(--d-accent)"
            >
                {name.main}
            </Lang>
            {name.second && text.secondary && (
                <Lang
                    language={text.secondary}
                    className="text-[3cqmin] text-(--d-muted)"
                >
                    {name.second}
                </Lang>
            )}
            <div className="relative my-[3cqmin] flex size-[58cqmin] items-center justify-center">
                <svg
                    viewBox="0 0 100 100"
                    className="absolute inset-0 -rotate-90"
                    aria-hidden
                >
                    <circle
                        cx="50"
                        cy="50"
                        r={radius}
                        fill="none"
                        stroke="var(--d-line)"
                        strokeWidth="1.2"
                    />
                    <circle
                        cx="50"
                        cy="50"
                        r={radius}
                        fill="none"
                        stroke="var(--d-accent)"
                        strokeWidth="1.8"
                        strokeLinecap="round"
                        strokeDasharray={circumference}
                        strokeDashoffset={circumference * model.phase.progress}
                        className="transition-[stroke-dashoffset] duration-1000 ease-linear"
                    />
                </svg>
                <div className="flex flex-col items-center gap-[1.4cqmin]">
                    <Lang
                        language={text.primary}
                        className="text-[3.2cqmin] text-(--d-muted)"
                    >
                        {text.t('iqama_in')}
                    </Lang>
                    <Ltr
                        className={cn(
                            'text-[16cqmin] leading-none font-semibold tracking-tight',
                            left < 1 && 'd-breathe text-(--d-accent)',
                        )}
                    >
                        {countdown(left)}
                    </Ltr>
                    {text.t2('iqama_in') && (
                        <Lang
                            language={text.secondary ?? text.primary}
                            className="text-[2.4cqmin] text-(--d-muted)"
                        >
                            {text.t2('iqama_in')}
                        </Lang>
                    )}
                </div>
            </div>
            <div className="flex items-center gap-[1.4cqmin] text-[3cqmin] text-(--d-muted)">
                <Lang language={text.primary}>{text.t('iqama')}</Lang>
                <Time
                    value={model.phase.event?.iqamaTime ?? null}
                    model={model}
                    className="text-(--d-fg)"
                />
            </div>
        </Layer>
    );
}

function IqamaMoment({ text }: { text: ScreenText }) {
    return (
        <Layer
            style={{
                background:
                    'radial-gradient(circle at 50% 50%, color-mix(in oklab, var(--d-accent) 18%, var(--d-bg)) 0%, var(--d-bg) 65%)',
            }}
        >
            <p
                lang="ar"
                dir="rtl"
                className="d-fade-up font-arabic text-[19cqmin] leading-tight font-bold text-(--d-accent)"
            >
                {text.in('ar', 'iqama')}
            </p>
            {text.translation && (
                <Lang
                    language={text.translation}
                    className="d-fade-up mt-[1cqmin] text-[6cqmin] font-semibold"
                >
                    {text.in(text.translation, 'iqama')}
                </Lang>
            )}
            <div className="mt-[6cqmin] flex flex-col items-center gap-[1cqmin] text-[3.2cqmin] text-(--d-muted)">
                <BellOff className="size-[5cqmin] text-(--d-fg)" aria-hidden />
                <Lang language={text.primary}>{text.t('silence_phones')}</Lang>
                {text.t2('silence_phones') && (
                    <Lang
                        language={text.secondary ?? text.primary}
                        className="text-[2.6cqmin]"
                    >
                        {text.t2('silence_phones')}
                    </Lang>
                )}
            </div>
        </Layer>
    );
}

function PrayerDim({
    model,
    text,
    prayer,
}: {
    model: ScreenModel;
    text: ScreenText;
    prayer: ScreenPrayer;
}) {
    const label = prayer === 'jumua' ? 'khutbah' : 'prayer_in_progress';

    return (
        <Layer className="bg-black" style={{ background: '#000' }}>
            <div className="d-drift flex flex-col items-center gap-[1.4cqmin] opacity-[0.22]">
                <BigClock
                    model={{
                        ...model,
                        settings: { ...model.settings, show_seconds: false },
                    }}
                    className="text-[9cqmin] text-white"
                />
                <Lang
                    language={text.primary}
                    className="text-[2.6cqmin] text-white"
                >
                    {text.t(label)}
                </Lang>
                <Lang
                    language={text.primary}
                    className="flex items-center gap-[0.8cqmin] text-[2cqmin] text-white"
                >
                    <BellOff className="size-[2.2cqmin]" aria-hidden />
                    {text.t('silence_phones')}
                </Lang>
            </div>
        </Layer>
    );
}
