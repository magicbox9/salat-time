import { Head, Link, router, usePage } from '@inertiajs/react';
import { ArrowLeft, ArrowRight } from 'lucide-react';
import { useState } from 'react';
import { toast } from 'sonner';
import { AyahList } from '@/components/quran/ayah-list';
import { BookmarkDialog } from '@/components/quran/bookmark-dialog';
import { QuranFonts } from '@/components/quran/quran-fonts';
import { ReaderToolbar } from '@/components/quran/reader-toolbar';
import { RecitationBar } from '@/components/quran/recitation-bar';
import { SurahHeader, SurahNav } from '@/components/quran/surah-header';
import {
    plainAyahText,
    readStored,
    surahName,
    writeStored,
} from '@/components/quran/types';
import type {
    Ayah,
    ReaderBookmark,
    Reciter,
    SurahMeta,
    Translation,
    TranslationOption,
} from '@/components/quran/types';
import { useReaderNavigation } from '@/components/quran/use-reader-navigation';
import { useRecitation } from '@/components/quran/use-recitation';
import { useT } from '@/lib/i18n';
import { useSignInUrl } from '@/lib/sign-in';
import { cn } from '@/lib/utils';

type Props = {
    surah: SurahMeta;
    ayat: Ayah[];
    basmala: string | null;
    previous: SurahMeta | null;
    next: SurahMeta | null;
    translationCode: string;
    translation: Translation | null;
    translations: TranslationOption[];
    reciters: Reciter[];
    bookmarks: ReaderBookmark[];
};

const SIZES = [22, 26, 30, 34, 40, 46];
const DEFAULT_SIZE = 2;
const PARTIAL = { preserveScroll: true, preserveState: true };

function storedSize(): number {
    const value = Number(readStored('quran:size') ?? DEFAULT_SIZE);

    return Number.isInteger(value) && value >= 0 && value < SIZES.length
        ? value
        : DEFAULT_SIZE;
}

export default function QuranShow({
    surah,
    ayat,
    basmala,
    previous,
    next,
    translationCode,
    translation,
    translations,
    reciters,
    bookmarks,
}: Props) {
    const t = useT();
    const { auth, dir, locale } = usePage().props;
    const signIn = useSignInUrl();
    const recitation = useRecitation({
        surah: surah.number,
        ayahCount: surah.ayah_count,
        reciters,
    });
    const { state } = recitation;
    const { highlight, goTo } = useReaderNavigation(surah.number, ayat, state);
    const [sizeIndex, setSizeIndex] = useState(storedSize);
    const [editing, setEditing] = useState<ReaderBookmark | null>(null);
    const active = state.status !== 'idle';
    const playing =
        active && state.status !== 'paused' && state.status !== 'error';
    const paused = state.status === 'paused';

    // "Play from here" on the paused ayah carries on instead of restarting.
    const playFrom = (ayah: number) =>
        paused && state.ayah === ayah && !state.basmala
            ? recitation.resume()
            : recitation.play(ayah);
    const Back = dir === 'rtl' ? ArrowRight : ArrowLeft;

    const resize = (delta: number) => {
        const value = Math.min(
            SIZES.length - 1,
            Math.max(0, sizeIndex + delta),
        );
        setSizeIndex(value);
        writeStored('quran:size', String(value));
    };

    const changeTranslation = (code: string) =>
        router.get(
            `/quran/${surah.number}`,
            { tr: code },
            {
                ...PARTIAL,
                only: ['translation', 'translationCode'],
                replace: true,
            },
        );

    const bookmark = (ayah: number) => {
        if (!auth.user) {
            toast.info(t('quran.bookmark_login'), {
                action: {
                    label: t('site.log_in'),
                    onClick: () => router.visit(signIn),
                },
            });

            return;
        }
        const existing = bookmarks.find((b) => b.ayah === ayah);
        if (existing) {
            setEditing(existing);

            return;
        }
        router.post(
            '/quran/bookmarks',
            { surah: surah.number, ayah },
            { ...PARTIAL, only: ['bookmarks'] },
        );
    };

    const copy = async (ayah: Ayah) => {
        const lines = [plainAyahText(ayah.text)];
        const meaning = translation?.ayat[ayah.ayah];
        if (meaning) {
            lines.push('', meaning.text);
        }
        lines.push(
            '',
            `— ${surah.name_ar} (${surah.name_en}) ${surah.number}:${ayah.ayah}`,
        );
        try {
            await navigator.clipboard.writeText(lines.join('\n'));
            toast.success(t('quran.copied'));
        } catch {
            toast.error(t('quran.copy_failed'));
        }
    };

    return (
        <>
            <Head title={`${surahName(surah, locale)} · ${t('quran.title')}`} />
            <QuranFonts preloadFace="hafs" />

            <div
                className={cn('mx-auto max-w-3xl space-y-6', active && 'pb-32')}
            >
                <Link
                    href="/quran"
                    className="inline-flex items-center gap-1.5 text-sm text-muted-foreground hover:text-primary"
                >
                    <Back className="size-4" />
                    {t('quran.all_surahs')}
                </Link>

                <SurahHeader surah={surah} basmala={basmala} />

                <ReaderToolbar
                    playing={playing}
                    paused={paused}
                    onPlay={() =>
                        paused
                            ? recitation.resume()
                            : recitation.play(
                                  state.status === 'error' &&
                                      state.ayah !== null
                                      ? state.ayah
                                      : 1,
                              )
                    }
                    onPause={recitation.pause}
                    canShrink={sizeIndex > 0}
                    canGrow={sizeIndex < SIZES.length - 1}
                    onShrink={() => resize(-1)}
                    onGrow={() => resize(1)}
                    reciters={reciters}
                    reciter={recitation.reciter}
                    onReciter={recitation.setReciter}
                    translations={translations}
                    translationCode={translationCode}
                    onTranslation={changeTranslation}
                    ayahCount={surah.ayah_count}
                    onGoTo={goTo}
                />

                {translation && (
                    <p className="text-xs text-muted-foreground">
                        <a
                            href={translation.source_url}
                            target="_blank"
                            rel="noopener noreferrer"
                            className="hover:underline"
                        >
                            {t('quran.translation_credit', {
                                title: translation.title,
                                version: translation.version,
                            })}
                        </a>
                    </p>
                )}

                {/* Keyed by surah so per-ayah state (open notes) never carries over. */}
                <AyahList
                    key={surah.number}
                    surah={surah.number}
                    ayat={ayat}
                    fontSize={SIZES[sizeIndex]}
                    translation={translation}
                    bookmarks={bookmarks}
                    recitation={state}
                    highlight={highlight}
                    onPlay={playFrom}
                    onPause={recitation.pause}
                    onBookmark={bookmark}
                    onCopy={(ayah) => void copy(ayah)}
                />

                <SurahNav previous={previous} next={next} dir={dir} />

                <p className="text-center text-xs text-muted-foreground">
                    {t('quran.text_credit')}
                </p>
            </div>

            <RecitationBar
                state={state}
                surah={surah}
                reciter={reciters.find((r) => r.id === recitation.reciter)}
                onPause={recitation.pause}
                onResume={recitation.resume}
                onRetry={() =>
                    state.ayah !== null && recitation.play(state.ayah)
                }
                onStop={recitation.stop}
                onNext={recitation.next}
                onPrevious={recitation.previous}
            />
            <BookmarkDialog
                surah={surah}
                bookmark={editing}
                onClose={() => setEditing(null)}
            />
        </>
    );
}
