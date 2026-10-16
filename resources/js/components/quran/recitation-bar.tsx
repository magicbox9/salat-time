import { usePage } from '@inertiajs/react';
import { Pause, Play, RotateCcw, SkipBack, SkipForward, X } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { Spinner } from '@/components/ui/spinner';
import { useT } from '@/lib/i18n';
import { surahName } from './types';
import type { Reciter, SurahMeta } from './types';
import type { RecitationState } from './use-recitation';

type Props = {
    state: RecitationState;
    surah: SurahMeta;
    reciter: Reciter | undefined;
    onPause: () => void;
    onResume: () => void;
    onRetry: () => void;
    onStop: () => void;
    onNext: () => void;
    onPrevious: () => void;
};

/** Floating player shown while a recitation is active. */
export function RecitationBar({
    state,
    surah,
    reciter,
    onPause,
    onResume,
    onRetry,
    onStop,
    onNext,
    onPrevious,
}: Props) {
    const t = useT();
    const { locale, dir } = usePage().props;

    if (state.status === 'idle' || state.ayah === null) {
        return null;
    }

    const Previous = dir === 'rtl' ? SkipForward : SkipBack;
    const Next = dir === 'rtl' ? SkipBack : SkipForward;
    const playing = state.status === 'playing' || state.status === 'loading';

    return (
        <div
            role="region"
            aria-label={t('quran.player')}
            className="fixed inset-x-3 bottom-3 z-40 mx-auto max-w-xl rounded-2xl border bg-card/95 p-3 shadow-xl backdrop-blur sm:bottom-5"
        >
            <div className="flex items-center gap-2">
                <Button
                    variant="ghost"
                    size="icon"
                    onClick={onPrevious}
                    disabled={state.ayah <= 1}
                    aria-label={t('quran.previous_ayah')}
                >
                    <Previous />
                </Button>
                {state.status === 'error' ? (
                    <Button
                        size="icon"
                        className="rounded-full"
                        onClick={onRetry}
                        aria-label={t('quran.resume')}
                    >
                        <RotateCcw />
                    </Button>
                ) : (
                    <Button
                        size="icon"
                        className="rounded-full"
                        onClick={playing ? onPause : onResume}
                        aria-label={
                            playing ? t('quran.pause') : t('quran.resume')
                        }
                    >
                        {state.status === 'loading' ? (
                            <Spinner />
                        ) : playing ? (
                            <Pause />
                        ) : (
                            <Play />
                        )}
                    </Button>
                )}
                <Button
                    variant="ghost"
                    size="icon"
                    onClick={onNext}
                    disabled={state.ayah >= surah.ayah_count}
                    aria-label={t('quran.next_ayah')}
                >
                    <Next />
                </Button>

                <div className="min-w-0 flex-1 px-1" aria-live="polite">
                    <p className="truncate text-sm font-medium">
                        <span dir="auto">{surahName(surah, locale)}</span>
                        <span aria-hidden> · </span>
                        {state.basmala
                            ? t('quran.basmala')
                            : t('quran.now_playing', { ayah: state.ayah })}
                    </p>
                    <p className="truncate text-xs text-muted-foreground">
                        {state.status === 'error'
                            ? t('quran.audio_error')
                            : reciter &&
                              (locale === 'ar'
                                  ? reciter.name_ar
                                  : reciter.name)}
                    </p>
                </div>

                <Button
                    variant="ghost"
                    size="icon"
                    onClick={onStop}
                    aria-label={t('quran.stop')}
                >
                    <X />
                </Button>
            </div>
            <p className="mt-1 text-center text-[11px] text-muted-foreground">
                {t('quran.audio_credit')}
            </p>
        </div>
    );
}
