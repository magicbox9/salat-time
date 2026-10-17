import { usePage } from '@inertiajs/react';
import { BadgeCheck, Home, MapPin, Star } from 'lucide-react';
import { useT } from '@/lib/i18n';
import { cn } from '@/lib/utils';
import { formatDistance } from './format';
import { NextPrayerLine } from './next-prayer-line';
import type { MosqueCard } from './types';

type Props = {
    mosque: MosqueCard;
    active: boolean;
    favorite: boolean;
    primary: boolean;
    onOpen: (mosque: MosqueCard) => void;
    onHover: (id: number | null) => void;
};

/** One nearby mosque in the results list. */
export function MosqueListItem({
    mosque,
    active,
    favorite,
    primary,
    onOpen,
    onHover,
}: Props) {
    const t = useT();
    const { locale } = usePage().props;
    const distance = formatDistance(mosque.distance_m, t, locale);

    return (
        <li>
            <button
                type="button"
                onClick={() => onOpen(mosque)}
                onMouseEnter={() => onHover(mosque.id)}
                onMouseLeave={() => onHover(null)}
                onFocus={() => onHover(mosque.id)}
                onBlur={() => onHover(null)}
                aria-current={active ? 'true' : undefined}
                className={cn(
                    'group w-full rounded-xl border bg-card/80 p-3 text-start transition-colors hover:border-primary/40 hover:bg-accent/60 focus-visible:ring-[3px] focus-visible:ring-ring/50 focus-visible:outline-none',
                    active && 'border-gold/70 bg-accent/70',
                )}
            >
                <div className="flex items-start gap-3">
                    <span
                        aria-hidden
                        title={
                            mosque.has_times
                                ? t('discover.times_published')
                                : undefined
                        }
                        className={cn(
                            'mt-1 size-2.5 shrink-0 rounded-full ring-2 ring-background',
                            mosque.has_times
                                ? 'bg-primary'
                                : 'bg-muted-foreground/50',
                        )}
                    />
                    <div className="min-w-0 flex-1">
                        <div className="flex items-start justify-between gap-2">
                            <p className="line-clamp-2 leading-snug font-medium">
                                {mosque.name}
                            </p>
                            {primary ? (
                                <Home
                                    className="mt-0.5 size-4 shrink-0 text-gold"
                                    aria-label={t('discover.my_mosque')}
                                />
                            ) : (
                                favorite && (
                                    <Star
                                        className="mt-0.5 size-4 shrink-0 fill-gold text-gold"
                                        aria-label={t('discover.saved')}
                                    />
                                )
                            )}
                        </div>
                        <p className="mt-0.5 flex items-center gap-1 text-xs text-muted-foreground">
                            <MapPin className="size-3 shrink-0" aria-hidden />
                            <span className="truncate">
                                {[mosque.postcode, mosque.city]
                                    .filter(Boolean)
                                    .join(' ') || '—'}
                            </span>
                            {distance && (
                                <>
                                    <span aria-hidden>·</span>
                                    <span className="shrink-0 tabular-nums">
                                        {distance}
                                    </span>
                                </>
                            )}
                            {mosque.verified && (
                                <BadgeCheck
                                    className="size-3.5 shrink-0 text-gold"
                                    aria-label={t('discover.verified')}
                                />
                            )}
                        </p>
                        {mosque.has_times && (
                            // The green dot says it visually; screen readers hear it here.
                            <span className="sr-only">
                                {t('discover.times_published')}
                            </span>
                        )}
                        {mosque.has_times || mosque.today ? (
                            <NextPrayerLine
                                today={mosque.today}
                                tomorrow={mosque.tomorrow}
                                timezone={mosque.timezone}
                                className="mt-2"
                            />
                        ) : (
                            <p className="mt-2 text-xs text-muted-foreground">
                                {t('discover.no_times_short')}
                            </p>
                        )}
                    </div>
                </div>
            </button>
        </li>
    );
}
