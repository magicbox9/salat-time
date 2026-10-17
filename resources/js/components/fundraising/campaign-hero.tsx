import { Link } from '@inertiajs/react';
import { BadgeCheck, MapPin } from 'lucide-react';
import { SiteLogoMark } from '@/components/site/site-logo';
import { useT } from '@/lib/i18n';
import { KindBadge } from './badges';
import { CampaignCover } from './campaign-cover';
import type { CampaignDetail } from './types';

/** Cover, kind, title, summary and the mosque the campaign belongs to. */
export function CampaignHero({ campaign }: { campaign: CampaignDetail }) {
    const t = useT();
    const mosque = campaign.mosque;

    return (
        <header className="space-y-5">
            <CampaignCover
                url={campaign.cover_url}
                eager
                className="aspect-[16/9] rounded-3xl shadow-sm ring-1 ring-black/5 sm:aspect-[2/1] dark:ring-white/10"
            >
                <div className="absolute start-4 bottom-4 sm:start-6 sm:bottom-6">
                    <KindBadge
                        kind={campaign.kind}
                        onImage
                        className="px-3 py-1.5 text-sm"
                    />
                </div>
            </CampaignCover>

            <div className="space-y-3">
                <h1 className="text-3xl leading-tight font-semibold tracking-tight text-balance sm:text-4xl">
                    {campaign.title}
                </h1>
                <p className="max-w-3xl text-lg text-pretty text-muted-foreground">
                    {campaign.summary}
                </p>
            </div>

            {mosque && (
                <Link
                    href={`/mosques/${mosque.slug}`}
                    className="group inline-flex max-w-full items-center gap-3 rounded-2xl border bg-card py-2 ps-2 pe-4 shadow-xs transition-colors hover:border-primary/40"
                >
                    {mosque.logo_url ? (
                        <img
                            src={mosque.logo_url}
                            alt=""
                            className="size-10 shrink-0 rounded-xl object-cover"
                        />
                    ) : (
                        <SiteLogoMark className="size-10 shrink-0 rounded-xl" />
                    )}
                    <span className="min-w-0">
                        <span className="block text-xs text-muted-foreground">
                            {t('fundraising.organised_by')}
                        </span>
                        <span className="flex items-center gap-1.5 font-medium">
                            <span className="truncate group-hover:underline">
                                {mosque.name}
                            </span>
                            {mosque.verified && (
                                <BadgeCheck
                                    className="size-4 shrink-0 text-gold"
                                    aria-label={t(
                                        'fundraising.verified_mosque',
                                    )}
                                />
                            )}
                        </span>
                    </span>
                    {mosque.city && (
                        <span className="hidden shrink-0 items-center gap-1 text-sm text-muted-foreground sm:inline-flex">
                            <MapPin className="size-3.5" aria-hidden />
                            {mosque.city}
                        </span>
                    )}
                </Link>
            )}
        </header>
    );
}
