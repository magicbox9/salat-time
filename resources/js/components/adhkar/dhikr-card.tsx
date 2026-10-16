import { Check, Pause, RotateCcw, Volume2 } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { countLabel } from '@/components/quran/types';
import { Spinner } from '@/components/ui/spinner';
import { useT } from '@/lib/i18n';
import { cn } from '@/lib/utils';
import { TasbihCounter } from './tasbih-counter';
import type { Dhikr } from './types';
import type { AdhkarAudioState } from './use-adhkar-audio';

type Props = {
    dhikr: Dhikr;
    position: number;
    total: number;
    count: number;
    active: boolean;
    audio: AdhkarAudioState;
    onTap: () => void;
    onReset: () => void;
    onListen: () => void;
};

/** One dhikr: the Arabic text, its tasbih counter, audio and references. */
export function DhikrCard({
    dhikr,
    position,
    total,
    count,
    active,
    audio,
    onTap,
    onReset,
    onListen,
}: Props) {
    const t = useT();
    const done = count >= dhikr.count;
    const mine = audio.id === dhikr.id ? audio.status : 'idle';

    return (
        <article
            id={`dhikr-${position}`}
            aria-label={t('adhkar.dhikr_number', { number: position })}
            className={cn(
                'scroll-mt-40 rounded-2xl border bg-card p-5 shadow-sm transition-all duration-300 sm:p-7',
                active && 'border-gold/60 shadow-md ring-1 ring-gold/25',
                done && 'bg-card/60',
            )}
        >
            <header className="flex items-center justify-between gap-3 text-xs text-muted-foreground">
                <span className="font-medium tabular-nums">
                    {t('adhkar.dhikr_of', { number: position, total })}
                </span>
                {done && (
                    <span className="inline-flex items-center gap-1 rounded-full bg-gold/15 px-2 py-0.5 font-medium text-foreground">
                        <Check className="size-3.5 text-gold" />
                        {t('adhkar.done')}
                    </span>
                )}
            </header>

            <p
                dir="rtl"
                lang="ar"
                className={cn(
                    'font-adhkar mt-4 text-start text-[1.55rem] leading-[2.15] text-foreground sm:text-[1.8rem]',
                    done && 'text-foreground/70',
                )}
            >
                {dhikr.arabic}
            </p>

            <div className="mt-5 flex flex-wrap items-center justify-between gap-4">
                <div className="space-y-1 text-sm">
                    <p>
                        <span className="text-muted-foreground">
                            {t('adhkar.repeat')}:{' '}
                        </span>
                        <span className="font-semibold tabular-nums">
                            {countLabel(t, 'adhkar.times', dhikr.count)}
                        </span>
                    </p>
                    {dhikr.count_desc && (
                        <p
                            dir="rtl"
                            lang="ar"
                            className="font-adhkar text-start text-base text-muted-foreground"
                        >
                            {dhikr.count_desc}
                        </p>
                    )}
                    {dhikr.audio && (
                        <div className="flex flex-wrap items-center gap-2 pt-1">
                            <Button
                                variant="outline"
                                size="sm"
                                onClick={onListen}
                                aria-pressed={mine === 'playing'}
                            >
                                {mine === 'loading' ? (
                                    <Spinner />
                                ) : mine === 'playing' ? (
                                    <Pause />
                                ) : (
                                    <Volume2 />
                                )}
                                {mine === 'playing'
                                    ? t('adhkar.pause')
                                    : t('adhkar.listen')}
                            </Button>
                            {mine !== 'idle' && (
                                <a
                                    href={dhikr.audio.credit_url}
                                    target="_blank"
                                    rel="noopener noreferrer"
                                    className="text-xs text-muted-foreground hover:underline"
                                >
                                    {mine === 'error'
                                        ? t('adhkar.audio_error')
                                        : t('adhkar.audio_credit', {
                                              source: dhikr.audio.credit,
                                          })}
                                </a>
                            )}
                        </div>
                    )}
                </div>
                <div className="flex items-center gap-2">
                    {count > 0 && (
                        <Button
                            variant="ghost"
                            size="icon"
                            className="text-muted-foreground"
                            onClick={onReset}
                            aria-label={t('adhkar.reset_dhikr')}
                            title={t('adhkar.reset_dhikr')}
                        >
                            <RotateCcw />
                        </Button>
                    )}
                    <TasbihCounter
                        count={Math.min(count, dhikr.count)}
                        total={dhikr.count}
                        onTap={onTap}
                    />
                </div>
            </div>

            {(dhikr.virtue || dhikr.meaning_en || dhikr.source) && (
                <dl className="mt-5 space-y-3 border-t pt-4 text-sm">
                    {dhikr.virtue && (
                        <div>
                            <dt className="text-xs font-semibold tracking-wide text-gold uppercase">
                                {t('adhkar.virtue')}
                            </dt>
                            <dd
                                dir="rtl"
                                lang="ar"
                                className="mt-1 text-start leading-relaxed text-muted-foreground"
                            >
                                {dhikr.virtue}
                            </dd>
                        </div>
                    )}
                    {dhikr.meaning_en && (
                        <div>
                            <dt className="text-xs font-semibold tracking-wide text-gold uppercase">
                                {t('adhkar.meaning_en')}
                            </dt>
                            <dd
                                dir="ltr"
                                lang="en"
                                className="mt-1 text-start leading-relaxed text-muted-foreground"
                            >
                                {dhikr.meaning_en}
                            </dd>
                        </div>
                    )}
                    {dhikr.source && (
                        <div>
                            <dt className="text-xs font-semibold tracking-wide text-muted-foreground uppercase">
                                {t('adhkar.source')}
                            </dt>
                            <dd
                                dir="rtl"
                                lang="ar"
                                className="mt-1 text-start text-xs leading-relaxed text-muted-foreground"
                            >
                                {dhikr.source}
                            </dd>
                        </div>
                    )}
                </dl>
            )}
        </article>
    );
}
