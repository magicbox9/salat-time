import { Fragment } from 'react';
import { useT } from '@/lib/i18n';
import { AyahItem } from './ayah-item';
import type { Ayah, ReaderBookmark, Translation } from './types';
import type { RecitationState } from './use-recitation';

type Props = {
    surah: number;
    ayat: Ayah[];
    fontSize: number;
    translation: Translation | null;
    bookmarks: ReaderBookmark[];
    recitation: RecitationState;
    highlight: number | null;
    onPlay: (ayah: number) => void;
    onPause: () => void;
    onBookmark: (ayah: number) => void;
    onCopy: (ayah: Ayah) => void;
};

/** Mushaf page (and juz) boundaries between ayat, as quiet dividers. */
function PageDivider({ ayah, newJuz }: { ayah: Ayah; newJuz: boolean }) {
    const t = useT();

    return (
        <div
            className="flex items-center gap-3 py-2 text-xs text-muted-foreground"
            aria-hidden
        >
            <span className="h-px flex-1 bg-border" />
            {t('quran.page', { number: ayah.page })}
            {newJuz && <> · {t('quran.juz', { number: ayah.juz })}</>}
            <span className="h-px flex-1 bg-border" />
        </div>
    );
}

export function AyahList({
    surah,
    ayat,
    fontSize,
    translation,
    bookmarks,
    recitation,
    highlight,
    onPlay,
    onPause,
    onBookmark,
    onCopy,
}: Props) {
    const bookmarked = new Set(bookmarks.map((b) => b.ayah));

    return (
        <div>
            {ayat.map((ayah, index) => {
                const before = ayat[index - 1];
                const playing =
                    recitation.ayah === ayah.ayah &&
                    !recitation.basmala &&
                    recitation.status !== 'idle' &&
                    recitation.status !== 'error'
                        ? recitation.status
                        : null;
                const meaning = translation?.ayat[ayah.ayah];

                return (
                    <Fragment key={ayah.ayah}>
                        {before && before.page !== ayah.page && (
                            <PageDivider
                                ayah={ayah}
                                newJuz={before.juz !== ayah.juz}
                            />
                        )}
                        <AyahItem
                            surah={surah}
                            ayah={ayah}
                            fontSize={fontSize}
                            translation={
                                meaning && translation
                                    ? {
                                          ...meaning,
                                          direction: translation.direction,
                                          language: translation.language,
                                      }
                                    : undefined
                            }
                            bookmarked={bookmarked.has(ayah.ayah)}
                            playing={playing}
                            highlighted={highlight === ayah.ayah}
                            onPlay={() => onPlay(ayah.ayah)}
                            onPause={onPause}
                            onBookmark={() => onBookmark(ayah.ayah)}
                            onCopy={() => onCopy(ayah)}
                        />
                    </Fragment>
                );
            })}
        </div>
    );
}
