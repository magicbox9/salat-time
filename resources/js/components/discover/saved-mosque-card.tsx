import { Link } from '@inertiajs/react';
import {
    ArrowUpRight,
    BadgeCheck,
    Home,
    MapPin,
    Navigation,
    Trash2,
} from 'lucide-react';
import { Badge } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';
import { useT } from '@/lib/i18n';
import { cn } from '@/lib/utils';
import { mapsUrl, placeLine } from './format';
import { NextPrayerLine } from './next-prayer-line';
import type { MosqueCard } from './types';

type Props = {
    mosque: MosqueCard;
    busy: boolean;
    onTogglePrimary: () => void;
    onRemove: () => void;
};

/** A saved mosque on /me/mosques: today's next prayer and quick actions. */
export function SavedMosqueCard({
    mosque,
    busy,
    onTogglePrimary,
    onRemove,
}: Props) {
    const t = useT();
    const href = `/mosques/${encodeURIComponent(mosque.slug)}`;
    const place = placeLine(mosque);

    return (
        <article
            className={cn(
                'flex flex-col rounded-xl border bg-card p-5 shadow-xs transition-colors',
                mosque.is_primary &&
                    'border-gold/60 bg-[color-mix(in_oklab,var(--gold)_6%,var(--card))]',
            )}
        >
            <div className="flex items-start justify-between gap-3">
                <div className="min-w-0">
                    {mosque.is_primary && (
                        <p className="mb-1 flex items-center gap-1.5 text-xs font-semibold tracking-wide text-gold uppercase">
                            <Home className="size-3.5" aria-hidden />
                            {t('discover.my_mosque')}
                        </p>
                    )}
                    <h2 className="text-lg leading-snug font-semibold">
                        <Link
                            href={href}
                            className="hover:underline hover:underline-offset-4"
                        >
                            {mosque.name}
                        </Link>
                        {mosque.verified && (
                            <BadgeCheck
                                className="ms-1.5 inline size-4 align-[-2px] text-gold"
                                aria-label={t('discover.verified')}
                            />
                        )}
                    </h2>
                    {place && (
                        <p className="mt-1 flex items-start gap-1 text-sm text-muted-foreground">
                            <MapPin
                                className="mt-0.5 size-3.5 shrink-0"
                                aria-hidden
                            />
                            <span>{place}</span>
                        </p>
                    )}
                </div>
                <Badge
                    variant={mosque.has_times ? 'secondary' : 'outline'}
                    className="shrink-0"
                >
                    {mosque.has_times
                        ? t('discover.times_published')
                        : t('discover.no_times_short')}
                </Badge>
            </div>

            <div className="mt-4 min-h-6 flex-1">
                {mosque.has_times ? (
                    <NextPrayerLine
                        today={mosque.today}
                        tomorrow={mosque.tomorrow}
                        timezone={mosque.timezone}
                    />
                ) : (
                    <p className="text-sm text-muted-foreground">
                        {t('site.no_times')}
                    </p>
                )}
            </div>

            <div className="mt-5 flex flex-wrap gap-2">
                <Button asChild size="sm">
                    <Link href={href}>
                        {t('discover.open_page')}
                        <ArrowUpRight className="rtl:-scale-x-100" />
                    </Link>
                </Button>
                <Button
                    size="sm"
                    variant="outline"
                    disabled={busy}
                    aria-pressed={mosque.is_primary}
                    onClick={onTogglePrimary}
                >
                    <Home className={cn(mosque.is_primary && 'text-gold')} />
                    {mosque.is_primary
                        ? t('discover.unset_my_mosque')
                        : t('discover.make_my_mosque')}
                </Button>
                <Button size="sm" variant="outline" asChild>
                    <a
                        href={mapsUrl(mosque)}
                        target="_blank"
                        rel="noopener noreferrer"
                    >
                        <Navigation />
                        {t('discover.directions')}
                    </a>
                </Button>
                <Button
                    size="sm"
                    variant="ghost"
                    disabled={busy}
                    onClick={onRemove}
                    className="ms-auto text-muted-foreground hover:text-destructive"
                >
                    <Trash2 />
                    {t('discover.remove')}
                </Button>
            </div>
        </article>
    );
}
