import { Head, Link } from '@inertiajs/react';
import {
    AlertTriangle,
    BadgeCheck,
    HandCoins,
    Hourglass,
    Landmark,
    ReceiptText,
} from 'lucide-react';
import { AdminShell } from '@/components/admin/admin-shell';
import { EmptyState } from '@/components/admin/empty-state';
import { Panel } from '@/components/admin/panel';
import { StatCard } from '@/components/admin/stat-card';
import type { AdminPageProps } from '@/components/admin/types';
import { AdminFundraisingNav } from '@/components/fundraising/admin-nav';
import { StateBadge } from '@/components/fundraising/badges';
import { useMoney } from '@/components/fundraising/format';
import { PayoutStatus } from '@/components/fundraising/payout-forms';
import type {
    AdminPayoutRow,
    CampaignCardData,
} from '@/components/fundraising/types';
import { Button } from '@/components/ui/button';
import { useT } from '@/lib/i18n';

type Props = AdminPageProps & {
    stats: {
        campaigns_pending: number;
        campaigns_active: number;
        payouts_to_verify: number;
        payouts_verified: number;
        raised: number;
        pledged: number;
        donations: number;
        currency: string;
    };
    pendingCampaigns: CampaignCardData[];
    payoutsToVerify: AdminPayoutRow[];
    paypal: { configured: boolean; webhook: boolean; mode: 'sandbox' | 'live' };
};

/** /admin/fundraising — what waits for a decision, and the platform's figures. */
export default function AdminFundraising({
    stats,
    pendingCampaigns,
    payoutsToVerify,
    paypal,
    pendingClaimsCount,
}: Props) {
    const t = useT();
    const money = useMoney();

    return (
        <>
            <Head title={t('fundraising.admin_title')} />
            <AdminShell
                title={t('fundraising.admin_title')}
                description={t('fundraising.admin_intro')}
                pendingClaimsCount={pendingClaimsCount}
            >
                <AdminFundraisingNav />

                {(!paypal.configured ||
                    !paypal.webhook ||
                    paypal.mode === 'sandbox') && (
                    <div className="flex items-start gap-3 rounded-xl border border-amber-500/40 bg-amber-500/10 p-4 text-sm">
                        <AlertTriangle
                            className="mt-0.5 size-4 shrink-0 text-amber-700 dark:text-amber-300"
                            aria-hidden
                        />
                        <div className="space-y-1">
                            {!paypal.configured && (
                                <p className="font-medium">
                                    {t('fundraising.admin_paypal_off')}
                                </p>
                            )}
                            {paypal.configured && !paypal.webhook && (
                                <p className="font-medium">
                                    {t('fundraising.admin_webhook_off')}
                                </p>
                            )}
                            {paypal.configured && paypal.mode === 'sandbox' && (
                                <p>{t('fundraising.admin_paypal_sandbox')}</p>
                            )}
                        </div>
                    </div>
                )}

                <div className="grid grid-cols-2 gap-3 sm:gap-4 lg:grid-cols-4">
                    <StatCard
                        label={t('fundraising.admin_stat_pending')}
                        value={stats.campaigns_pending}
                        icon={Hourglass}
                        href="/admin/fundraising/campaigns"
                        highlight={stats.campaigns_pending > 0}
                    />
                    <StatCard
                        label={t('fundraising.admin_stat_to_verify')}
                        value={stats.payouts_to_verify}
                        icon={Landmark}
                        href="/admin/fundraising/payouts"
                        highlight={stats.payouts_to_verify > 0}
                    />
                    <StatCard
                        label={t('fundraising.admin_stat_active')}
                        value={stats.campaigns_active}
                        icon={HandCoins}
                        href="/admin/fundraising/campaigns?status=active"
                    />
                    <StatCard
                        label={t('fundraising.admin_stat_donations')}
                        value={stats.donations}
                        icon={ReceiptText}
                        hint={`${money(stats.raised, stats.currency)} · ${t('fundraising.pledged_short', { amount: money(stats.pledged, stats.currency) })}`}
                    />
                </div>

                <Panel
                    title={t('fundraising.admin_pending_title')}
                    description={t('fundraising.admin_pending_intro')}
                    actions={
                        <Button asChild variant="outline" size="sm">
                            <Link href="/admin/fundraising/campaigns">
                                {t('fundraising.see_all')}
                            </Link>
                        </Button>
                    }
                >
                    {pendingCampaigns.length === 0 ? (
                        <EmptyState
                            icon={BadgeCheck}
                            title={t('fundraising.admin_nothing_pending')}
                        />
                    ) : (
                        <ul className="divide-y">
                            {pendingCampaigns.map((campaign) => (
                                <li key={campaign.id}>
                                    <Link
                                        href={`/admin/fundraising/campaigns/${campaign.slug}`}
                                        className="flex items-center justify-between gap-3 py-3 hover:text-primary"
                                    >
                                        <span className="min-w-0">
                                            <span className="block truncate font-medium">
                                                {campaign.title}
                                            </span>
                                            <span className="block truncate text-sm text-muted-foreground">
                                                {campaign.mosque?.name}
                                            </span>
                                        </span>
                                        <StateBadge state={campaign.state} />
                                    </Link>
                                </li>
                            ))}
                        </ul>
                    )}
                </Panel>

                <Panel
                    title={t('fundraising.admin_payouts_title')}
                    description={t('fundraising.admin_payouts_intro')}
                    actions={
                        <Button asChild variant="outline" size="sm">
                            <Link href="/admin/fundraising/payouts">
                                {t('fundraising.see_all')}
                            </Link>
                        </Button>
                    }
                >
                    {payoutsToVerify.length === 0 ? (
                        <EmptyState
                            icon={BadgeCheck}
                            title={t('fundraising.admin_nothing_to_verify')}
                        />
                    ) : (
                        <ul className="divide-y">
                            {payoutsToVerify.map((payout) => (
                                <li
                                    key={payout.id}
                                    className="flex items-center justify-between gap-3 py-3"
                                >
                                    <span className="min-w-0">
                                        <span className="block truncate font-medium">
                                            {payout.mosque?.name}
                                        </span>
                                        <span className="block truncate text-sm text-muted-foreground">
                                            {t(
                                                `fundraising.method_${payout.type}`,
                                            )}{' '}
                                            ·{' '}
                                            <span dir="ltr">
                                                {payout.paypal_email ??
                                                    payout.paypal_merchant_id ??
                                                    payout.iban_masked}
                                            </span>
                                        </span>
                                    </span>
                                    <PayoutStatus payout={payout} />
                                </li>
                            ))}
                        </ul>
                    )}
                </Panel>
            </AdminShell>
        </>
    );
}
