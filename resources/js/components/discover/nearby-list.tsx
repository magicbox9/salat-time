import { usePage } from '@inertiajs/react';
import { RefreshCw, SearchX } from 'lucide-react';
import { useState } from 'react';
import { Button } from '@/components/ui/button';
import { Skeleton } from '@/components/ui/skeleton';
import { intlLocale, useT } from '@/lib/i18n';
import { cn } from '@/lib/utils';
import { MosqueListItem } from './mosque-list-item';
import type { MosqueCard, Origin } from './types';

type Props = {
    origin: Origin;
    mosques: MosqueCard[] | null;
    radiusKm: number | null;
    loading: boolean;
    failed: boolean;
    selectedId: number | null;
    isFavorite: (id: number) => boolean;
    isPrimary: (id: number) => boolean;
    onOpen: (mosque: MosqueCard) => void;
    onHover: (id: number | null) => void;
    onRetry: () => void;
    /** The phone sheet already shows the count in its own handle. */
    showCount?: boolean;
    className?: string;
};

/** The mosques found around the chosen place, nearest first. */
export function NearbyList({
    origin,
    mosques,
    radiusKm,
    loading,
    failed,
    selectedId,
    isFavorite,
    isPrimary,
    onOpen,
    onHover,
    onRetry,
    showCount = true,
    className,
}: Props) {
    const t = useT();
    const { locale } = usePage().props;
    const [onlyTimes, setOnlyTimes] = useState(false);
    const shown = (mosques ?? []).filter((m) => !onlyTimes || m.has_times);
    const withTimes = (mosques ?? []).filter((m) => m.has_times).length;
    const radius =
        radiusKm === null
            ? ''
            : new Intl.NumberFormat(intlLocale(locale)).format(radiusKm);

    return (
        <section
            aria-live="polite"
            aria-busy={loading}
            className={cn('flex min-h-0 flex-col', className)}
        >
            <header className="flex flex-wrap items-baseline justify-between gap-x-3 gap-y-1 px-1 pb-3">
                <div className="min-w-0">
                    <h2
                        className={cn(
                            'truncate text-sm font-semibold',
                            !showCount && 'sr-only',
                        )}
                    >
                        {loading || mosques === null
                            ? t('discover.searching_near', {
                                  place: origin.label,
                              })
                            : t('discover.found_count', {
                                  count: mosques.length,
                                  radius,
                              })}
                    </h2>
                    {!loading && mosques !== null && (
                        <p className="truncate text-xs text-muted-foreground">
                            {t('discover.around', { place: origin.label })}
                        </p>
                    )}
                </div>
                {!loading &&
                    withTimes > 0 &&
                    withTimes < (mosques?.length ?? 0) && (
                        <button
                            type="button"
                            aria-pressed={onlyTimes}
                            onClick={() => setOnlyTimes((v) => !v)}
                            className={cn(
                                'rounded-full border px-2.5 py-1 text-xs font-medium transition-colors',
                                onlyTimes
                                    ? 'border-primary bg-primary text-primary-foreground'
                                    : 'hover:bg-accent',
                            )}
                        >
                            {t('discover.only_with_times')}
                        </button>
                    )}
            </header>

            <div className="-mx-1 min-h-0 flex-1 overflow-y-auto overscroll-contain px-1 pb-1">
                {loading && mosques === null ? (
                    <ul className="space-y-2" aria-label={t('site.loading')}>
                        {[0, 1, 2, 3].map((i) => (
                            <li key={i}>
                                <Skeleton className="h-[5.5rem] rounded-xl" />
                            </li>
                        ))}
                    </ul>
                ) : failed ? (
                    <div className="rounded-xl border border-dashed p-5 text-center text-sm">
                        <p className="text-muted-foreground">
                            {t('discover.nearby_failed')}
                        </p>
                        <Button
                            variant="outline"
                            size="sm"
                            className="mt-3"
                            onClick={onRetry}
                        >
                            <RefreshCw />
                            {t('discover.retry')}
                        </Button>
                    </div>
                ) : shown.length === 0 ? (
                    <div className="flex flex-col items-center rounded-xl border border-dashed px-4 py-8 text-center">
                        <SearchX
                            className="size-6 text-muted-foreground"
                            aria-hidden
                        />
                        <p className="mt-2 text-sm font-medium">
                            {t('discover.none_title')}
                        </p>
                        <p className="mt-1 text-xs text-muted-foreground">
                            {t('discover.none_text')}
                        </p>
                    </div>
                ) : (
                    <ul
                        className={cn(
                            'space-y-2 transition-opacity',
                            loading && 'opacity-60',
                        )}
                    >
                        {shown.map((mosque) => (
                            <MosqueListItem
                                key={mosque.id}
                                mosque={mosque}
                                active={mosque.id === selectedId}
                                favorite={isFavorite(mosque.id)}
                                primary={isPrimary(mosque.id)}
                                onOpen={onOpen}
                                onHover={onHover}
                            />
                        ))}
                    </ul>
                )}
            </div>
        </section>
    );
}
