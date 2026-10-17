import { Link } from '@inertiajs/react';
import { ArrowRight, HandCoins } from 'lucide-react';
import { useEffect, useState } from 'react';
import { api } from '@/components/mosque/api';
import { useT } from '@/lib/i18n';
import { KindBadge } from './badges';
import { CampaignCover } from './campaign-cover';
import { useDaysLeft } from './campaign-card';
import { useMoney } from './format';
import { ProgressBar } from './progress-bar';
import type { CampaignCardData } from './types';

/** Refreshes the figures now and then while the page stays open. */
const REFRESH_MS = 60_000;

/**
 * CONTRACT C2: the mosque's open campaigns with their progress, for the
 * mosque's page and the home screen. Loads GET /mosques/{slug}/campaigns.json
 * itself and shows nothing at all when the mosque has no open campaign.
 */
export function MosqueCampaigns({ mosqueSlug }: { mosqueSlug: string }) {
    const t = useT();
    const [campaigns, setCampaigns] = useState<CampaignCardData[]>([]);

    useEffect(() => {
        let alive = true;
        const load = () => {
            if (document.hidden) {
                return;
            }

            api<{ campaigns: CampaignCardData[] }>(
                'GET',
                `/mosques/${mosqueSlug}/campaigns.json`,
            )
                .then((data) => {
                    if (alive) {
                        setCampaigns(data.campaigns ?? []);
                    }
                })
                .catch(() => undefined);
        };
        load();
        const timer = window.setInterval(load, REFRESH_MS);

        return () => {
            alive = false;
            window.clearInterval(timer);
        };
    }, [mosqueSlug]);

    if (campaigns.length === 0) {
        return null;
    }

    return (
        <section
            aria-labelledby={`campaigns-${mosqueSlug}`}
            className="space-y-3"
        >
            <div className="flex items-end justify-between gap-3">
                <h2
                    id={`campaigns-${mosqueSlug}`}
                    className="flex items-center gap-2 text-lg font-semibold tracking-tight"
                >
                    <HandCoins className="size-5 text-gold" aria-hidden />
                    {t('fundraising.widget_title')}
                </h2>
                <Link
                    href={`/mosques/${mosqueSlug}/campaigns`}
                    className="inline-flex items-center gap-1 text-sm font-medium text-primary hover:underline"
                >
                    {t('fundraising.see_all')}
                    <ArrowRight className="size-4 rtl:rotate-180" aria-hidden />
                </Link>
            </div>
            <ul className="grid gap-3 sm:grid-cols-2">
                {campaigns.slice(0, 4).map((campaign) => (
                    <li key={campaign.id}>
                        <CompactCampaign campaign={campaign} />
                    </li>
                ))}
            </ul>
        </section>
    );
}

function CompactCampaign({ campaign }: { campaign: CampaignCardData }) {
    const t = useT();
    const money = useMoney();
    const daysLeft = useDaysLeft()(campaign);

    return (
        <article className="group relative flex h-full gap-4 overflow-hidden rounded-2xl border bg-card p-3 shadow-xs transition-colors hover:border-primary/30">
            <CampaignCover
                url={campaign.cover_url}
                className="hidden aspect-square w-24 shrink-0 rounded-xl min-[400px]:block"
            />
            <div className="flex min-w-0 flex-1 flex-col gap-2 py-0.5">
                <KindBadge
                    kind={campaign.kind}
                    className="self-start px-2 py-0.5"
                />
                <h3 className="line-clamp-2 leading-snug font-semibold">
                    <Link
                        href={`/campaigns/${campaign.slug}`}
                        className="after:absolute after:inset-0 focus-visible:outline-none after:focus-visible:rounded-2xl after:focus-visible:ring-[3px] after:focus-visible:ring-ring/50"
                    >
                        {campaign.title}
                    </Link>
                </h3>
                <div className="mt-auto space-y-1.5">
                    <ProgressBar percent={campaign.percent} />
                    <p className="flex items-baseline justify-between gap-2 text-xs text-muted-foreground">
                        <span className="truncate">
                            <span
                                className="font-semibold text-foreground"
                                dir="ltr"
                            >
                                {money(campaign.raised, campaign.currency)}
                            </span>{' '}
                            {t('fundraising.of_goal', {
                                goal: money(campaign.goal, campaign.currency),
                            })}
                        </span>
                        {daysLeft && (
                            <span className="shrink-0">{daysLeft}</span>
                        )}
                    </p>
                </div>
            </div>
        </article>
    );
}
