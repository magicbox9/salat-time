import { Head, usePage } from '@inertiajs/react';
import { Search } from 'lucide-react';
import { useEffect, useState } from 'react';
import { QuranFonts } from '@/components/quran/quran-fonts';
import {
    BookmarkList,
    BookmarksLoginHint,
    ContinueCard,
} from '@/components/quran/reading-shortcuts';
import { SurahCard } from '@/components/quran/surah-card';
import { normalizeSearch, readStored } from '@/components/quran/types';
import type { IndexBookmark, SurahMeta } from '@/components/quran/types';
import { Input } from '@/components/ui/input';
import { useT } from '@/lib/i18n';

type Props = {
    surahs: SurahMeta[];
    bookmarks: IndexBookmark[];
    continue: IndexBookmark | null;
};

/** Where the reader last was on this device (written by the reader page). */
function useLastPosition(): { surah: number; ayah: number } | null {
    const [last, setLast] = useState<{ surah: number; ayah: number } | null>(
        null,
    );

    useEffect(() => {
        try {
            const value = JSON.parse(readStored('quran:last') ?? 'null');
            if (
                Number.isInteger(value?.surah) &&
                Number.isInteger(value?.ayah)
            ) {
                setLast({ surah: value.surah, ayah: value.ayah });
            }
        } catch {
            // Ignore a malformed value.
        }
    }, []);

    return last;
}

function matches(surah: SurahMeta, query: string): boolean {
    if (/^\d+$/.test(query)) {
        return String(surah.number).startsWith(query);
    }

    const needle = normalizeSearch(query).replace(/ /g, '');

    return (
        normalizeSearch(surah.name_en).replace(/ /g, '').includes(needle) ||
        normalizeSearch(surah.name_ar).replace(/ /g, '').includes(needle)
    );
}

export default function QuranIndex({
    surahs,
    bookmarks,
    continue: latest,
}: Props) {
    const t = useT();
    const { auth, locale } = usePage().props;
    const [query, setQuery] = useState('');
    const last = useLastPosition();
    const trimmed = query.trim();
    const visible =
        trimmed === '' ? surahs : surahs.filter((s) => matches(s, trimmed));
    const lastSurah = last ? surahs[last.surah - 1] : undefined;

    return (
        <>
            <Head title={t('quran.title')} />
            <QuranFonts />

            <header className="flex flex-col gap-6 md:flex-row md:items-end md:justify-between">
                <div className="max-w-2xl">
                    {locale !== 'ar' && (
                        <p
                            dir="rtl"
                            lang="ar"
                            aria-hidden
                            className="font-quran mb-2 text-4xl leading-tight text-gold sm:text-5xl"
                        >
                            القرآن الكريم
                        </p>
                    )}
                    <h1 className="text-2xl font-semibold sm:text-3xl">
                        {t('quran.title')}
                    </h1>
                    <p className="mt-2 text-muted-foreground">
                        {t('quran.intro')}
                    </p>
                </div>
                <label className="relative w-full md:w-80">
                    <span className="sr-only">{t('quran.search_label')}</span>
                    <Search className="pointer-events-none absolute start-3 top-1/2 size-4 -translate-y-1/2 text-muted-foreground" />
                    <Input
                        type="search"
                        value={query}
                        onChange={(event) => setQuery(event.target.value)}
                        placeholder={t('quran.search_placeholder')}
                        className="h-11 rounded-xl ps-9"
                        maxLength={60}
                    />
                </label>
            </header>

            {trimmed === '' && (
                <section className="mt-8 grid gap-4 lg:grid-cols-2">
                    {latest ? (
                        <ContinueCard
                            title={t('quran.continue_reading')}
                            surah={{
                                number: latest.surah,
                                name_en: latest.name_en,
                                name_ar: latest.name_ar,
                            }}
                            ayah={latest.ayah}
                            note={latest.note}
                        />
                    ) : (
                        lastSurah &&
                        last && (
                            <ContinueCard
                                title={t('quran.last_opened')}
                                surah={lastSurah}
                                ayah={last.ayah}
                            />
                        )
                    )}
                    <div className="space-y-3">
                        <h2 className="text-sm font-semibold tracking-wide text-muted-foreground uppercase">
                            {t('quran.bookmarks')}
                        </h2>
                        {auth.user ? (
                            <BookmarkList bookmarks={bookmarks} />
                        ) : (
                            <BookmarksLoginHint />
                        )}
                    </div>
                </section>
            )}

            <section className="mt-10" aria-labelledby="surahs-heading">
                <div className="mb-4 flex items-baseline justify-between gap-3">
                    <h2 id="surahs-heading" className="text-lg font-semibold">
                        {t('quran.surahs_count')}
                    </h2>
                </div>
                {visible.length === 0 ? (
                    <p className="rounded-xl border border-dashed p-8 text-center text-muted-foreground">
                        {t('quran.no_results', { query: trimmed })}
                    </p>
                ) : (
                    <div className="grid gap-3 sm:grid-cols-2 xl:grid-cols-3">
                        {visible.map((surah) => (
                            <SurahCard key={surah.number} surah={surah} />
                        ))}
                    </div>
                )}
            </section>

            <p className="mt-10 text-center text-xs text-muted-foreground">
                {t('quran.text_credit')}
            </p>
        </>
    );
}
