import { Head, Link } from '@inertiajs/react';
import { ArrowRight, HandCoins } from 'lucide-react';
import { AdminShell } from '@/components/admin/admin-shell';
import { EmptyState } from '@/components/admin/empty-state';
import { useApplyFilters } from '@/components/admin/filters';
import { Pagination } from '@/components/admin/pagination';
import type { AdminPageProps, Paginated } from '@/components/admin/types';
import { AdminFundraisingNav } from '@/components/fundraising/admin-nav';
import { KindBadge, StateBadge } from '@/components/fundraising/badges';
import { CampaignCover } from '@/components/fundraising/campaign-cover';
import { useMoney } from '@/components/fundraising/format';
import type {
    CampaignCardData,
    CampaignStatus,
} from '@/components/fundraising/types';
import { useT } from '@/lib/i18n';
import { cn } from '@/lib/utils';

type Props = AdminPageProps & {
    campaigns: Paginated<CampaignCardData>;
    status: CampaignStatus | 'all';
};

const FILTERS: (CampaignStatus | 'all')[] = [
    'pending',
    'active',
    'rejected',
    'draft',
    'completed',
    'closed',
    'all',
];

/** /admin/fundraising/campaigns — campaigns by status, those to review first. */
export default function AdminCampaigns({
    campaigns,
    status,
    pendingClaimsCount,
}: Props) {
    const t = useT();
    const money = useMoney();
    const apply = useApplyFilters('/admin/fundraising/campaigns', { status });

    return (
        <>
            <Head title={t('fundraising.admin_campaigns')} />
            <AdminShell
                title={t('fundraising.admin_campaigns')}
                description={t('fundraising.admin_campaigns_intro')}
                pendingClaimsCount={pendingClaimsCount}
            >
                <AdminFundraisingNav />

                <div className="-mx-4 overflow-x-auto px-4">
                    <div className="flex w-max gap-1 rounded-xl bg-muted p-1">
                        {FILTERS.map((filter) => (
                            <button
                                key={filter}
                                type="button"
                                aria-pressed={filter === status}
                                onClick={() => apply({ status: filter })}
                                className={cn(
                                    'rounded-lg px-3 py-1.5 text-sm font-medium whitespace-nowrap transition-colors',
                                    filter === status
                                        ? 'bg-background shadow-sm'
                                        : 'text-muted-foreground hover:text-foreground',
                                )}
                            >
                                {filter === 'all'
                                    ? t('fundraising.filter_all')
                                    : t(`fundraising.state_${filter}`)}
                            </button>
                        ))}
                    </div>
                </div>

                {campaigns.data.length === 0 ? (
                    <EmptyState
                        icon={HandCoins}
                        title={t('fundraising.admin_no_campaigns')}
                    />
                ) : (
                    <ul className="divide-y overflow-hidden rounded-xl border bg-card shadow-sm">
                        {campaigns.data.map((campaign) => (
                            <li key={campaign.id}>
                                <Link
                                    href={`/admin/fundraising/campaigns/${campaign.slug}`}
                                    className="flex items-center gap-4 p-4 transition-colors hover:bg-muted/40"
                                >
                                    <CampaignCover
                                        url={campaign.cover_url}
                                        className="hidden aspect-[4/3] w-24 shrink-0 rounded-lg sm:block"
                                    />
                                    <div className="min-w-0 flex-1 space-y-1">
                                        <div className="flex flex-wrap items-center gap-2">
                                            <StateBadge
                                                state={campaign.state}
                                            />
                                            <KindBadge
                                                kind={campaign.kind}
                                                className="px-2 py-0.5"
                                            />
                                        </div>
                                        <p className="truncate font-medium">
                                            {campaign.title}
                                        </p>
                                        <p className="truncate text-sm text-muted-foreground">
                                            {[
                                                campaign.mosque?.name,
                                                campaign.mosque?.city,
                                            ]
                                                .filter(Boolean)
                                                .join(' · ')}{' '}
                                            ·{' '}
                                            <span dir="ltr">
                                                {money(
                                                    campaign.raised,
                                                    campaign.currency,
                                                )}
                                            </span>{' '}
                                            /{' '}
                                            <span dir="ltr">
                                                {money(
                                                    campaign.goal,
                                                    campaign.currency,
                                                )}
                                            </span>
                                        </p>
                                    </div>
                                    <ArrowRight
                                        className="size-4 shrink-0 text-muted-foreground rtl:rotate-180"
                                        aria-hidden
                                    />
                                </Link>
                            </li>
                        ))}
                    </ul>
                )}

                <Pagination page={campaigns} />
            </AdminShell>
        </>
    );
}
