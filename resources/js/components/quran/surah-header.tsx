import { Link } from '@inertiajs/react';
import { ChevronLeft, ChevronRight } from 'lucide-react';
import { useT } from '@/lib/i18n';
import { cn } from '@/lib/utils';
import { SurahNumber } from './surah-card';
import { countLabel } from './types';
import type { SurahMeta } from './types';

/** The surah title plate, with the basmala when the surah opens with it. */
export function SurahHeader({
    surah,
    basmala,
}: {
    surah: SurahMeta;
    basmala: string | null;
}) {
    const t = useT();

    return (
        <section className="relative overflow-hidden rounded-2xl border bg-card px-4 py-8 text-center shadow-sm sm:px-10 sm:py-10">
            <div
                aria-hidden
                className="pointer-events-none absolute inset-0 bg-[radial-gradient(circle_at_top,var(--gold)_0%,transparent_55%)] opacity-15"
            />
            <div className="relative">
                <div className="flex items-center justify-center gap-2 text-xs font-medium tracking-wide text-gold uppercase">
                    <SurahNumber
                        number={surah.number}
                        className="size-9 text-foreground"
                    />
                    {t('quran.surah_number', { number: surah.number })}
                </div>
                <h1 className="mt-3">
                    <span
                        dir="rtl"
                        lang="ar"
                        className="font-quran block text-5xl leading-snug text-primary sm:text-6xl"
                    >
                        {surah.name_ar}
                    </span>
                    <span className="mt-1 block text-lg font-medium" dir="ltr">
                        {surah.name_en}
                    </span>
                </h1>
                <p className="mt-2 text-sm text-muted-foreground">
                    {countLabel(t, 'quran.ayat', surah.ayah_count)}
                    <span aria-hidden> · </span>
                    {t('quran.juz', { number: surah.juz })}
                    <span aria-hidden> · </span>
                    {surah.page === surah.end_page
                        ? t('quran.page', { number: surah.page })
                        : t('quran.pages', {
                              from: surah.page,
                              to: surah.end_page,
                          })}
                </p>
                {basmala && (
                    <p
                        dir="rtl"
                        lang="ar"
                        className="font-quran mx-auto mt-8 max-w-xl border-t border-gold/30 pt-6 text-3xl leading-loose text-foreground sm:text-4xl"
                    >
                        {basmala}
                    </p>
                )}
            </div>
        </section>
    );
}

type NavProps = {
    previous: SurahMeta | null;
    next: SurahMeta | null;
    dir: 'ltr' | 'rtl';
};

/** Previous / next surah, arrows pointing the reading direction. */
export function SurahNav({ previous, next, dir }: NavProps) {
    const t = useT();
    const Back = dir === 'rtl' ? ChevronRight : ChevronLeft;
    const Forward = dir === 'rtl' ? ChevronLeft : ChevronRight;

    const link = (surah: SurahMeta, label: string, forward: boolean) => (
        <Link
            href={`/quran/${surah.number}`}
            className={cn(
                'group flex flex-1 items-center gap-3 rounded-xl border bg-card p-4 transition-colors hover:border-primary/40',
                forward && 'flex-row-reverse text-end',
            )}
        >
            {forward ? (
                <Forward className="size-5 shrink-0 text-muted-foreground group-hover:text-primary" />
            ) : (
                <Back className="size-5 shrink-0 text-muted-foreground group-hover:text-primary" />
            )}
            <span className="min-w-0 flex-1">
                <span className="block text-xs text-muted-foreground">
                    {label}
                </span>
                <span className="block truncate font-medium">
                    <span dir="ltr">{surah.name_en}</span>{' '}
                    <span
                        dir="rtl"
                        lang="ar"
                        className="font-quran text-primary"
                    >
                        {surah.name_ar}
                    </span>
                </span>
            </span>
        </Link>
    );

    return (
        <nav
            className="flex flex-col gap-3 sm:flex-row"
            aria-label={t('quran.all_surahs')}
        >
            {previous ? (
                link(previous, t('quran.previous_surah'), false)
            ) : (
                <span className="hidden flex-1 sm:block" />
            )}
            {next ? (
                link(next, t('quran.next_surah'), true)
            ) : (
                <span className="hidden flex-1 sm:block" />
            )}
        </nav>
    );
}
