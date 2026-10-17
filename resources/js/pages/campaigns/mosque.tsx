import { Head, Link } from '@inertiajs/react';
import { ArrowLeft, BadgeCheck, HandCoins, Settings2 } from 'lucide-react';
import { CampaignCard } from '@/components/fundraising/campaign-card';
import type { CampaignCardData } from '@/components/fundraising/types';
import { SiteLogoMark } from '@/components/site/site-logo';
import { Button } from '@/components/ui/button';
import { useT } from '@/lib/i18n';
import type { MosqueSummary } from '@/types/mosque';

type Props = {
    mosque: MosqueSummary;
    open: CampaignCardData[];
    ended: CampaignCardData[];
    canManage: boolean;
};

/** /mosques/{slug}/campaigns — one mosque's campaigns, open ones first. */
export default function MosqueCampaignsPage({
    mosque,
    open,
    ended,
    canManage,
}: Props) {
    const t = useT();
    const title = t('fundraising.mosque_campaigns_title', {
        mosque: mosque.name,
    });

    return (
        <>
            <Head title={title} />
            <div className="mx-auto max-w-6xl space-y-8">
                <Link
                    href={`/mosques/${mosque.slug}`}
                    className="inline-flex items-center gap-1.5 text-sm text-muted-foreground transition-colors hover:text-foreground"
                >
                    <ArrowLeft className="size-4 rtl:rotate-180" aria-hidden />
                    {t('fundraising.back_to_mosque')}
                </Link>

                <header className="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
                    <div className="flex min-w-0 items-center gap-4">
                        {mosque.logo_url ? (
                            <img
                                src={mosque.logo_url}
                                alt=""
                                className="size-14 shrink-0 rounded-2xl object-cover"
                            />
                        ) : (
                            <SiteLogoMark className="size-14 rounded-2xl" />
                        )}
                        <div className="min-w-0">
                            <p className="flex items-center gap-1.5 text-sm text-muted-foreground">
                                <span className="truncate">{mosque.name}</span>
                                {mosque.verified && (
                                    <BadgeCheck
                                        className="size-4 shrink-0 text-gold"
                                        aria-hidden
                                    />
                                )}
                            </p>
                            <h1 className="text-2xl font-semibold tracking-tight sm:text-3xl">
                                {t('fundraising.mosque_campaigns_heading')}
                            </h1>
                        </div>
                    </div>
                    {canManage && (
                        <Button asChild variant="outline">
                            <Link href={`/manage/${mosque.slug}/campaigns`}>
                                <Settings2 className="size-4" aria-hidden />
                                {t('fundraising.manage_campaigns')}
                            </Link>
                        </Button>
                    )}
                </header>

                {open.length === 0 && ended.length === 0 ? (
                    <div className="rounded-3xl border border-dashed px-6 py-16 text-center">
                        <HandCoins
                            className="mx-auto size-10 text-gold"
                            aria-hidden
                        />
                        <p className="mt-4 text-lg font-medium">
                            {t('fundraising.mosque_none')}
                        </p>
                        <p className="mx-auto mt-1 max-w-md text-sm text-muted-foreground">
                            {t('fundraising.mosque_none_body')}
                        </p>
                        <Button asChild variant="outline" className="mt-5">
                            <Link href="/campaigns">
                                {t('fundraising.see_every_campaign')}
                            </Link>
                        </Button>
                    </div>
                ) : (
                    <>
                        {open.length > 0 && (
                            <section
                                aria-labelledby="open-campaigns"
                                className="space-y-4"
                            >
                                <h2
                                    id="open-campaigns"
                                    className="text-lg font-semibold"
                                >
                                    {t('fundraising.tab_open')}
                                </h2>
                                <ul className="grid gap-5 sm:grid-cols-2 xl:grid-cols-3">
                                    {open.map((campaign) => (
                                        <li key={campaign.id} className="flex">
                                            <CampaignCard
                                                campaign={campaign}
                                                showMosque={false}
                                                className="w-full"
                                            />
                                        </li>
                                    ))}
                                </ul>
                            </section>
                        )}
                        {ended.length > 0 && (
                            <section
                                aria-labelledby="ended-campaigns"
                                className="space-y-4"
                            >
                                <h2
                                    id="ended-campaigns"
                                    className="text-lg font-semibold"
                                >
                                    {t('fundraising.tab_ended')}
                                </h2>
                                <ul className="grid gap-5 sm:grid-cols-2 xl:grid-cols-3">
                                    {ended.map((campaign) => (
                                        <li key={campaign.id} className="flex">
                                            <CampaignCard
                                                campaign={campaign}
                                                showMosque={false}
                                                className="w-full opacity-90"
                                            />
                                        </li>
                                    ))}
                                </ul>
                            </section>
                        )}
                    </>
                )}
            </div>
        </>
    );
}
