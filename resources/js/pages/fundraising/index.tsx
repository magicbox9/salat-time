import { Link } from '@inertiajs/react';
import { ArrowRight, HandCoins, Info, Plus } from 'lucide-react';
import { KindBadge, StateBadge } from '@/components/fundraising/badges';
import { CampaignCover } from '@/components/fundraising/campaign-cover';
import { useMoney } from '@/components/fundraising/format';
import { FundraisingNav } from '@/components/fundraising/manage-nav';
import { ProblemsNotice } from '@/components/fundraising/problems-notice';
import { ProgressBar } from '@/components/fundraising/progress-bar';
import type {
    AvailableMethods,
    CampaignCardData,
    EligibilityProblem,
} from '@/components/fundraising/types';
import { ManageLayout } from '@/components/manage/manage-layout';
import { Button } from '@/components/ui/button';
import { useT } from '@/lib/i18n';
import type { MosqueSummary } from '@/types/mosque';

type Props = {
    mosque: MosqueSummary;
    campaigns: (CampaignCardData & { review_note: string | null })[];
    problems: EligibilityProblem[];
    allowable: AvailableMethods;
    paypalEnabled: boolean;
    pendingTransfers: number;
};

/** /manage/{mosque}/campaigns — the mosque's campaigns, and what is needed to start one. */
export default function ManageCampaigns({
    mosque,
    campaigns,
    problems,
    pendingTransfers,
}: Props) {
    const t = useT();
    const money = useMoney();
    const base = `/manage/${mosque.slug}/campaigns`;

    return (
        <ManageLayout
            mosque={mosque}
            title={t('fundraising.manage_title')}
            description={t('fundraising.manage_intro')}
            actions={
                <Button asChild>
                    <Link href={`${base}/create`}>
                        <Plus className="size-4" aria-hidden />
                        {t('fundraising.new_campaign')}
                    </Link>
                </Button>
            }
        >
            <FundraisingNav
                mosqueSlug={mosque.slug}
                toConfirm={pendingTransfers}
            />

            <ProblemsNotice problems={problems} mosqueSlug={mosque.slug} />

            {pendingTransfers > 0 && (
                <Link
                    href={`/manage/${mosque.slug}/donations?status=pending&method=bank`}
                    className="flex items-center justify-between gap-3 rounded-2xl border border-gold/50 bg-gold/10 px-4 py-3 text-sm font-medium transition-colors hover:bg-gold/15"
                >
                    {t('fundraising.transfers_to_confirm', {
                        count: pendingTransfers,
                    })}
                    <ArrowRight
                        className="size-4 shrink-0 rtl:rotate-180"
                        aria-hidden
                    />
                </Link>
            )}

            <p className="flex items-start gap-2 rounded-2xl bg-muted/50 p-4 text-sm text-muted-foreground">
                <Info
                    className="mt-0.5 size-4 shrink-0 text-primary"
                    aria-hidden
                />
                {t('fundraising.manage_how')}
            </p>

            {campaigns.length === 0 ? (
                <div className="rounded-3xl border border-dashed px-6 py-14 text-center">
                    <HandCoins
                        className="mx-auto size-10 text-gold"
                        aria-hidden
                    />
                    <p className="mt-4 font-medium">
                        {t('fundraising.manage_empty')}
                    </p>
                    <p className="mx-auto mt-1 max-w-md text-sm text-muted-foreground">
                        {t('fundraising.manage_empty_body')}
                    </p>
                </div>
            ) : (
                <ul className="divide-y overflow-hidden rounded-3xl border bg-card shadow-xs">
                    {campaigns.map((campaign) => (
                        <li key={campaign.id}>
                            <Link
                                href={`${base}/${campaign.slug}`}
                                className="flex flex-col gap-4 p-4 transition-colors hover:bg-muted/40 sm:flex-row sm:items-center"
                            >
                                <CampaignCover
                                    url={campaign.cover_url}
                                    className="hidden aspect-[4/3] w-28 shrink-0 rounded-xl sm:block"
                                />
                                <div className="min-w-0 flex-1 space-y-2">
                                    <div className="flex flex-wrap items-center gap-2">
                                        <StateBadge state={campaign.state} />
                                        <KindBadge
                                            kind={campaign.kind}
                                            className="px-2 py-0.5"
                                        />
                                    </div>
                                    <p className="truncate font-semibold">
                                        {campaign.title}
                                    </p>
                                    <ProgressBar
                                        percent={campaign.percent}
                                        pledgedPercent={
                                            campaign.goal
                                                ? (campaign.pledged * 100) /
                                                  campaign.goal
                                                : 0
                                        }
                                    />
                                    <p className="text-xs text-muted-foreground">
                                        <span
                                            className="font-semibold text-foreground"
                                            dir="ltr"
                                        >
                                            {money(
                                                campaign.raised,
                                                campaign.currency,
                                            )}
                                        </span>{' '}
                                        {t('fundraising.of_goal', {
                                            goal: money(
                                                campaign.goal,
                                                campaign.currency,
                                            ),
                                        })}
                                        {campaign.pledged > 0 &&
                                            ` · ${t('fundraising.pledged_short', { amount: money(campaign.pledged, campaign.currency) })}`}
                                    </p>
                                    {campaign.status === 'rejected' &&
                                        campaign.review_note && (
                                            <p className="line-clamp-2 text-xs text-red-700 dark:text-red-300">
                                                {t('fundraising.review_note', {
                                                    note: campaign.review_note,
                                                })}
                                            </p>
                                        )}
                                </div>
                                <ArrowRight
                                    className="hidden size-4 shrink-0 text-muted-foreground sm:block rtl:rotate-180"
                                    aria-hidden
                                />
                            </Link>
                        </li>
                    ))}
                </ul>
            )}
        </ManageLayout>
    );
}
