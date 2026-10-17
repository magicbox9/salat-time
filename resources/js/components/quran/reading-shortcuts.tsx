import { Link, router, usePage } from '@inertiajs/react';
import { BookMarked, BookOpen, LogIn, Trash2 } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { useT } from '@/lib/i18n';
import { useSignInUrl } from '@/lib/sign-in';
import { surahName } from './types';
import type { IndexBookmark, SurahMeta } from './types';

type ContinueProps = {
    surah: Pick<SurahMeta, 'number' | 'name_en' | 'name_ar'>;
    ayah: number;
    title: string;
    note?: string | null;
};

/** "Continue reading": the latest bookmark, or the last position on this device. */
export function ContinueCard({ surah, ayah, title, note }: ContinueProps) {
    const t = useT();
    const { locale } = usePage().props;

    return (
        <Link
            href={`/quran/${surah.number}#ayah-${ayah}`}
            className="group relative flex items-center gap-4 overflow-hidden rounded-xl bg-gradient-to-br from-primary to-primary/80 p-5 text-primary-foreground shadow-sm transition-shadow hover:shadow-lg focus-visible:ring-[3px] focus-visible:ring-ring/50 focus-visible:outline-none sm:p-6"
        >
            <span className="grid size-12 shrink-0 place-items-center rounded-full bg-white/15">
                <BookOpen className="size-6" />
            </span>
            <span className="min-w-0 flex-1">
                <span className="block text-xs font-medium tracking-wide text-gold uppercase">
                    {title}
                </span>
                <span className="mt-1 block truncate text-lg font-semibold">
                    {t('quran.continue_at', {
                        surah: surahName(surah, locale),
                        ayah,
                    })}
                </span>
                {note && (
                    <span className="mt-0.5 block truncate text-sm opacity-80">
                        {note}
                    </span>
                )}
            </span>
            <span
                dir="rtl"
                lang="ar"
                className="font-quran hidden shrink-0 text-3xl sm:block"
            >
                {surah.name_ar}
            </span>
        </Link>
    );
}

export function BookmarkList({ bookmarks }: { bookmarks: IndexBookmark[] }) {
    const t = useT();
    const { locale } = usePage().props;

    const remove = (bookmark: IndexBookmark) =>
        router.delete(`/quran/bookmarks/${bookmark.id}`, {
            preserveScroll: true,
            preserveState: true,
            only: ['bookmarks', 'continue'],
        });

    if (bookmarks.length === 0) {
        return (
            <p className="rounded-xl border border-dashed p-5 text-sm text-muted-foreground">
                {t('quran.no_bookmarks')}
            </p>
        );
    }

    return (
        <ul className="grid gap-2 sm:grid-cols-2">
            {bookmarks.map((bookmark) => (
                <li
                    key={bookmark.id}
                    className="flex items-center gap-2 rounded-xl border bg-card p-2 ps-4"
                >
                    <BookMarked className="size-4 shrink-0 text-gold" />
                    <Link
                        href={`/quran/${bookmark.surah}#ayah-${bookmark.ayah}`}
                        className="min-w-0 flex-1 rounded-md py-1 hover:text-primary"
                    >
                        <span className="block truncate text-sm font-medium">
                            {surahName(bookmark, locale)}{' '}
                            <span
                                className="text-muted-foreground tabular-nums"
                                dir="ltr"
                            >
                                {bookmark.surah}:{bookmark.ayah}
                            </span>
                        </span>
                        {bookmark.note && (
                            <span className="block truncate text-xs text-muted-foreground">
                                {bookmark.note}
                            </span>
                        )}
                    </Link>
                    <Button
                        variant="ghost"
                        size="icon"
                        className="shrink-0 text-muted-foreground hover:text-destructive"
                        aria-label={t('quran.bookmark_remove')}
                        title={t('quran.bookmark_remove')}
                        onClick={() => remove(bookmark)}
                    >
                        <Trash2 />
                    </Button>
                </li>
            ))}
        </ul>
    );
}

/** Shown to visitors instead of their bookmarks. */
export function BookmarksLoginHint() {
    const t = useT();
    const signIn = useSignInUrl();

    return (
        <div className="flex flex-wrap items-center justify-between gap-3 rounded-xl border border-dashed p-4 text-sm text-muted-foreground">
            <span>{t('quran.bookmarks_login')}</span>
            <Button asChild variant="outline" size="sm">
                <Link href={signIn}>
                    <LogIn />
                    {t('site.log_in')}
                </Link>
            </Button>
        </div>
    );
}
