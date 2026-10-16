import { Link } from '@inertiajs/react';
import {
    BadgeCheck,
    CalendarClock,
    CalendarX,
    ExternalLink,
    MapPin,
    Pencil,
} from 'lucide-react';
import { Badge } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';
import { useT } from '@/lib/i18n';
import type { MosqueSummary } from '@/types/mosque';
import { InfoList, InfoRow, Panel } from './panel';

export type AdminMosqueDetails = MosqueSummary & {
    association?: string | null;
    phone?: string | null;
    email?: string | null;
    website?: string | null;
};

/** Mosque facts with quick status badges (times published, verified). */
export function MosqueStatusBadges({ mosque }: { mosque: MosqueSummary }) {
    const t = useT();

    return (
        <div className="flex flex-wrap gap-1.5">
            {mosque.has_times ? (
                <Badge
                    variant="outline"
                    className="rounded-full border-primary/30 text-primary"
                >
                    <CalendarClock aria-hidden />
                    {t('admin.has_times')}
                </Badge>
            ) : (
                <Badge
                    variant="outline"
                    className="rounded-full text-muted-foreground"
                >
                    <CalendarX aria-hidden />
                    {t('admin.no_times')}
                </Badge>
            )}
            {mosque.verified && (
                <Badge
                    variant="outline"
                    className="rounded-full border-gold/50 bg-gold/10 text-amber-800 dark:text-gold"
                >
                    <BadgeCheck aria-hidden />
                    {t('admin.verified')}
                </Badge>
            )}
            <Badge variant="secondary" className="rounded-full">
                {t(`admin.source_${mosque.source}`)}
            </Badge>
        </div>
    );
}

/** The mosque a request is about (admin claim page). */
export function MosqueCard({ mosque }: { mosque: AdminMosqueDetails }) {
    const t = useT();
    const place = [
        mosque.address,
        [mosque.postcode, mosque.city].filter(Boolean).join(' '),
    ]
        .filter(Boolean)
        .join(', ');

    return (
        <Panel title={t('admin.mosque')}>
            <div className="space-y-4">
                <div>
                    <p className="font-medium">{mosque.name}</p>
                    {place && (
                        <p className="mt-1 flex items-start gap-1.5 text-sm text-muted-foreground">
                            <MapPin
                                className="mt-0.5 size-3.5 shrink-0"
                                aria-hidden
                            />
                            {place}
                        </p>
                    )}
                </div>
                <MosqueStatusBadges mosque={mosque} />
                {(mosque.association ||
                    mosque.phone ||
                    mosque.email ||
                    mosque.website) && (
                    <InfoList>
                        {mosque.association && (
                            <InfoRow label={t('admin.association')}>
                                {mosque.association}
                            </InfoRow>
                        )}
                        {mosque.phone && (
                            <InfoRow label={t('admin.phone')}>
                                <span dir="ltr">{mosque.phone}</span>
                            </InfoRow>
                        )}
                        {mosque.email && (
                            <InfoRow label={t('admin.email')}>
                                <span dir="ltr">{mosque.email}</span>
                            </InfoRow>
                        )}
                        {mosque.website && (
                            <InfoRow label={t('admin.website')}>
                                <span dir="ltr">{mosque.website}</span>
                            </InfoRow>
                        )}
                    </InfoList>
                )}
                <div className="flex flex-wrap gap-2">
                    <Button asChild size="sm" variant="outline">
                        <Link href={`/admin/mosques/${mosque.slug}`}>
                            <Pencil />
                            {t('admin.edit_mosque')}
                        </Link>
                    </Button>
                    <Button asChild size="sm" variant="ghost">
                        <a
                            href={`/mosques/${mosque.slug}`}
                            target="_blank"
                            rel="noreferrer"
                        >
                            <ExternalLink />
                            {t('admin.public_page')}
                        </a>
                    </Button>
                    <Button asChild size="sm" variant="ghost">
                        <a
                            href={mosque.google_maps_url}
                            target="_blank"
                            rel="noreferrer noopener"
                        >
                            <MapPin />
                            {t('admin.on_map')}
                        </a>
                    </Button>
                </div>
            </div>
        </Panel>
    );
}
