import { usePage } from '@inertiajs/react';
import { BadgeCheck, MapPin, X } from 'lucide-react';
import { TodayTimes } from '@/components/prayer/today-times';
import { Button } from '@/components/ui/button';
import { Skeleton } from '@/components/ui/skeleton';
import { useT } from '@/lib/i18n';
import { cn } from '@/lib/utils';
import { formatDistance, placeLine } from './format';
import { MosqueActions } from './mosque-actions';
import type { MosquePin } from './types';
import { useMosqueTimes } from './use-mosque-times';

type Props = {
    mosque: MosquePin;
    welcome: boolean;
    favorite: boolean;
    /** The visitor's own mosque (signed in: primary; guest: cookie). */
    chosen: boolean;
    busy: boolean;
    choosing: boolean;
    onToggleFavorite: () => void;
    onChoose: () => void;
    onClose: () => void;
    className?: string;
};

/** The selected mosque: today's published times and what you can do with it. */
export function MosquePanel({
    mosque,
    welcome,
    favorite,
    chosen,
    busy,
    choosing,
    onToggleFavorite,
    onChoose,
    onClose,
    className,
}: Props) {
    const t = useT();
    const { locale } = usePage().props;
    const { times, loading, failed } = useMosqueTimes(mosque.slug);
    const distance = formatDistance(mosque.distance_m, t, locale);
    const place = placeLine(mosque);

    return (
        <section
            aria-labelledby="discover-panel-title"
            className={cn(
                'flex max-h-full flex-col rounded-2xl border bg-background/95 shadow-2xl backdrop-blur-xl',
                className,
            )}
        >
            <header className="flex items-start gap-3 border-b p-4">
                <div className="min-w-0 flex-1">
                    {welcome && (
                        <p className="mb-1 text-xs font-semibold tracking-wide text-gold uppercase">
                            {t('discover.your_mosque')}
                        </p>
                    )}
                    <h2
                        id="discover-panel-title"
                        className="text-lg leading-snug font-semibold"
                    >
                        {mosque.name}
                        {mosque.verified && (
                            <BadgeCheck
                                className="ms-1.5 inline size-4 align-[-2px] text-gold"
                                aria-label={t('discover.verified')}
                            />
                        )}
                    </h2>
                    {(place || distance) && (
                        <p className="mt-1 flex items-start gap-1 text-sm text-muted-foreground">
                            <MapPin
                                className="mt-0.5 size-3.5 shrink-0"
                                aria-hidden
                            />
                            <span>
                                {place}
                                {place && distance && ' · '}
                                {distance && (
                                    <span className="tabular-nums">
                                        {distance}
                                    </span>
                                )}
                            </span>
                        </p>
                    )}
                </div>
                <Button
                    variant="ghost"
                    size="icon"
                    className="-me-2 -mt-1 shrink-0"
                    onClick={onClose}
                    aria-label={t('discover.close')}
                >
                    <X />
                </Button>
            </header>

            <div className="min-h-0 flex-1 space-y-4 overflow-y-auto overscroll-contain p-4">
                {loading ? (
                    <div className="space-y-2" aria-label={t('site.loading')}>
                        <Skeleton className="h-10" />
                        {[0, 1, 2, 3, 4, 5].map((i) => (
                            <Skeleton key={i} className="h-6" />
                        ))}
                    </div>
                ) : failed ? (
                    <p className="text-sm text-muted-foreground">
                        {t('site.error_generic')}
                    </p>
                ) : (
                    <TodayTimes
                        today={times?.today ?? null}
                        tomorrow={times?.tomorrow ?? null}
                        timezone={times?.timezone ?? 'UTC'}
                        compact
                    />
                )}
                <MosqueActions
                    mosque={mosque}
                    favorite={favorite}
                    chosen={chosen}
                    busy={busy}
                    choosing={choosing}
                    onToggleFavorite={onToggleFavorite}
                    onChoose={onChoose}
                />
            </div>
        </section>
    );
}
