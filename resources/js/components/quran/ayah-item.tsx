import { Bookmark, BookmarkCheck, Copy, Pause, Play } from 'lucide-react';
import { useState } from 'react';
import { Button } from '@/components/ui/button';
import { Spinner } from '@/components/ui/spinner';
import { useT } from '@/lib/i18n';
import { cn } from '@/lib/utils';
import type { Ayah } from './types';

type Props = {
    surah: number;
    ayah: Ayah;
    fontSize: number;
    translation?: {
        text: string;
        notes: string | null;
        direction: 'ltr' | 'rtl';
        language: string;
    };
    bookmarked: boolean;
    /** This ayah is the one being recited. */
    playing: 'loading' | 'playing' | 'paused' | null;
    highlighted: boolean;
    onPlay: () => void;
    onPause: () => void;
    onBookmark: () => void;
    onCopy: () => void;
};

/** One ayah: the verbatim KFGQPC text, its actions and the optional translation. */
export function AyahItem({
    surah,
    ayah,
    fontSize,
    translation,
    bookmarked,
    playing,
    highlighted,
    onPlay,
    onPause,
    onBookmark,
    onCopy,
}: Props) {
    const t = useT();
    const [showNotes, setShowNotes] = useState(false);
    const isPlaying = playing === 'playing' || playing === 'loading';

    return (
        <article
            id={`ayah-${ayah.ayah}`}
            aria-label={t('quran.ayah', { number: ayah.ayah })}
            className={cn(
                'scroll-mt-40 rounded-xl border border-transparent px-3 py-5 transition-colors duration-500 sm:px-6',
                playing && 'border-gold/50 bg-gold/10',
                !playing && highlighted && 'border-primary/30 bg-primary/5',
            )}
        >
            <p
                dir="rtl"
                lang="ar"
                className="font-quran text-start text-foreground"
                style={{ fontSize: `${fontSize}px`, lineHeight: 2.15 }}
            >
                {ayah.text}
            </p>

            {translation && (
                <div
                    dir={translation.direction}
                    lang={translation.language}
                    className="mt-3 text-start"
                >
                    <p className="leading-relaxed text-muted-foreground">
                        {translation.text}
                    </p>
                    {translation.notes && (
                        <>
                            <button
                                type="button"
                                onClick={() => setShowNotes((v) => !v)}
                                aria-expanded={showNotes}
                                className="mt-1 text-xs font-medium text-primary hover:underline"
                            >
                                {showNotes
                                    ? t('quran.translation_hide_notes')
                                    : t('quran.translation_notes')}
                            </button>
                            {showNotes && (
                                <p className="mt-2 rounded-lg bg-muted px-3 py-2 text-xs leading-relaxed whitespace-pre-line text-muted-foreground">
                                    {translation.notes}
                                </p>
                            )}
                        </>
                    )}
                </div>
            )}

            <div className="mt-3 flex items-center gap-1 text-muted-foreground">
                <span
                    className="me-1 rounded-full bg-muted px-2.5 py-0.5 text-xs font-medium tabular-nums"
                    dir="ltr"
                >
                    {surah}:{ayah.ayah}
                </span>
                <Button
                    variant="ghost"
                    size="icon"
                    className={cn('size-8', isPlaying && 'text-gold')}
                    onClick={isPlaying ? onPause : onPlay}
                    aria-label={
                        isPlaying ? t('quran.pause') : t('quran.play_from_here')
                    }
                    title={
                        isPlaying ? t('quran.pause') : t('quran.play_from_here')
                    }
                >
                    {playing === 'loading' ? (
                        <Spinner />
                    ) : isPlaying ? (
                        <Pause />
                    ) : (
                        <Play />
                    )}
                </Button>
                <Button
                    variant="ghost"
                    size="icon"
                    className={cn('size-8', bookmarked && 'text-gold')}
                    onClick={onBookmark}
                    aria-pressed={bookmarked}
                    aria-label={
                        bookmarked
                            ? t('quran.bookmark_edit')
                            : t('quran.bookmark_add')
                    }
                    title={
                        bookmarked
                            ? t('quran.bookmark_edit')
                            : t('quran.bookmark_add')
                    }
                >
                    {bookmarked ? (
                        <BookmarkCheck className="fill-gold/20" />
                    ) : (
                        <Bookmark />
                    )}
                </Button>
                <Button
                    variant="ghost"
                    size="icon"
                    className="size-8"
                    onClick={onCopy}
                    aria-label={t('quran.copy')}
                    title={t('quran.copy')}
                >
                    <Copy />
                </Button>
            </div>
        </article>
    );
}
