import { Link } from '@inertiajs/react';
import { useT } from '@/lib/i18n';
import { cn } from '@/lib/utils';
import { countLabel } from './types';
import type { SurahMeta } from './types';

/** The surah number inside an eight-pointed star, as in printed mushafs. */
export function SurahNumber({
    number,
    className,
}: {
    number: number;
    className?: string;
}) {
    return (
        <span
            className={cn(
                'relative grid size-11 shrink-0 place-items-center',
                className,
            )}
        >
            <span className="absolute inset-1.5 rounded-md border border-gold/70 bg-gold/10 transition-colors group-hover:bg-gold/20" />
            <span className="absolute inset-1.5 rotate-45 rounded-md border border-gold/70 transition-colors" />
            <span
                className="relative text-sm font-semibold tabular-nums"
                dir="ltr"
            >
                {number}
            </span>
        </span>
    );
}

export function SurahCard({ surah }: { surah: SurahMeta }) {
    const t = useT();

    return (
        <Link
            href={`/quran/${surah.number}`}
            className="group flex items-center gap-4 rounded-xl border bg-card p-4 transition-all hover:-translate-y-0.5 hover:border-primary/40 hover:shadow-md focus-visible:ring-[3px] focus-visible:ring-ring/50 focus-visible:outline-none"
        >
            <SurahNumber number={surah.number} />
            <div className="min-w-0 flex-1">
                <div className="truncate font-medium" dir="ltr">
                    <span className="sr-only">
                        {t('quran.surah_number', { number: surah.number })}{' '}
                        —{' '}
                    </span>
                    {surah.name_en}
                </div>
                <div className="mt-0.5 text-xs text-muted-foreground">
                    {countLabel(t, 'quran.ayat', surah.ayah_count)}
                    <span aria-hidden> · </span>
                    {t('quran.juz', { number: surah.juz })}
                    <span aria-hidden> · </span>
                    {t('quran.page', { number: surah.page })}
                </div>
            </div>
            <span
                dir="rtl"
                lang="ar"
                className="font-quran shrink-0 text-2xl leading-none text-primary"
            >
                {surah.name_ar}
            </span>
        </Link>
    );
}
