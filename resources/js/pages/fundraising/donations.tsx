import { router } from '@inertiajs/react';
import { Download, ReceiptText } from 'lucide-react';
import { DonationRows } from '@/components/fundraising/donation-rows';
import { useMoney } from '@/components/fundraising/format';
import { FundraisingNav } from '@/components/fundraising/manage-nav';
import type {
    DonationMethod,
    DonationStatus,
    ManagedDonation,
} from '@/components/fundraising/types';
import { ManageLayout } from '@/components/manage/manage-layout';
import { Pager } from '@/components/manage/pager';
import type { Paginated } from '@/components/manage/pager';
import { Button } from '@/components/ui/button';
import { useT } from '@/lib/i18n';
import { cn } from '@/lib/utils';
import type { MosqueSummary } from '@/types/mosque';

type Filters = {
    campaign: string | null;
    status: DonationStatus | null;
    method: DonationMethod | null;
};

type Props = {
    mosque: MosqueSummary;
    donations: Paginated<ManagedDonation>;
    filters: Filters;
    campaigns: { slug: string; title: string }[];
    totals: {
        raised: number;
        pledged: number;
        to_confirm: number;
        currency: string;
    };
};

const STATUSES: (DonationStatus | null)[] = [
    null,
    'pending',
    'completed',
    'cancelled',
    'refunded',
];

/** /manage/{mosque}/donations — every gift, the transfers to confirm, and the CSV for the accounts. */
export default function ManageDonations({
    mosque,
    donations,
    filters,
    campaigns,
    totals,
}: Props) {
    const t = useT();
    const money = useMoney();
    const base = `/manage/${mosque.slug}/donations`;

    const query = (next: Partial<Filters>) => {
        const merged = { ...filters, ...next };

        return Object.fromEntries(
            Object.entries(merged).filter(([, value]) => value),
        ) as Record<string, string>;
    };
    const visit = (next: Partial<Filters>) =>
        router.get(base, query(next), {
            preserveScroll: true,
            preserveState: true,
        });
    const exportUrl = `${base}/export.csv?${new URLSearchParams(query({})).toString()}`;

    return (
        <ManageLayout
            mosque={mosque}
            title={t('fundraising.donations_title')}
            description={t('fundraising.donations_intro')}
            actions={
                <Button asChild variant="outline">
                    <a href={exportUrl}>
                        <Download className="size-4" aria-hidden />
                        {t('fundraising.export_csv')}
                    </a>
                </Button>
            }
        >
            <FundraisingNav
                mosqueSlug={mosque.slug}
                toConfirm={totals.to_confirm}
            />

            <dl className="grid gap-3 sm:grid-cols-3">
                {[
                    [
                        t('fundraising.raised'),
                        money(totals.raised, totals.currency),
                    ],
                    [
                        t('fundraising.pledged'),
                        money(totals.pledged, totals.currency),
                    ],
                    [t('fundraising.to_confirm'), String(totals.to_confirm)],
                ].map(([label, value]) => (
                    <div
                        key={label}
                        className="rounded-2xl border bg-card px-4 py-3 shadow-xs"
                    >
                        <dt className="text-xs text-muted-foreground">
                            {label}
                        </dt>
                        <dd className="text-xl font-semibold" dir="ltr">
                            <span className="inline-block">{value}</span>
                        </dd>
                    </div>
                ))}
            </dl>

            <div className="flex flex-col gap-3 lg:flex-row lg:items-center lg:justify-between">
                <div className="-mx-4 overflow-x-auto px-4">
                    <div className="flex w-max gap-1 rounded-xl bg-muted p-1">
                        {STATUSES.map((status) => (
                            <button
                                key={status ?? 'all'}
                                type="button"
                                aria-pressed={filters.status === status}
                                onClick={() => visit({ status })}
                                className={cn(
                                    'rounded-lg px-3 py-1.5 text-sm font-medium whitespace-nowrap transition-colors',
                                    filters.status === status
                                        ? 'bg-background shadow-sm'
                                        : 'text-muted-foreground hover:text-foreground',
                                )}
                            >
                                {status
                                    ? t(`fundraising.donation_${status}`)
                                    : t('fundraising.filter_all')}
                            </button>
                        ))}
                    </div>
                </div>
                <div className="flex flex-wrap gap-2">
                    <select
                        aria-label={t('fundraising.filter_campaign')}
                        value={filters.campaign ?? ''}
                        onChange={(event) =>
                            visit({ campaign: event.target.value || null })
                        }
                        className="h-9 max-w-64 rounded-md border border-input bg-background px-3 text-sm shadow-xs"
                    >
                        <option value="">
                            {t('fundraising.all_campaigns_option')}
                        </option>
                        {campaigns.map((campaign) => (
                            <option key={campaign.slug} value={campaign.slug}>
                                {campaign.title}
                            </option>
                        ))}
                    </select>
                    <select
                        aria-label={t('fundraising.filter_method')}
                        value={filters.method ?? ''}
                        onChange={(event) =>
                            visit({
                                method: (event.target.value ||
                                    null) as DonationMethod | null,
                            })
                        }
                        className="h-9 rounded-md border border-input bg-background px-3 text-sm shadow-xs"
                    >
                        <option value="">
                            {t('fundraising.all_methods_option')}
                        </option>
                        <option value="paypal">
                            {t('fundraising.method_paypal')}
                        </option>
                        <option value="bank">
                            {t('fundraising.method_bank')}
                        </option>
                    </select>
                </div>
            </div>

            {donations.data.length === 0 ? (
                <div className="rounded-3xl border border-dashed px-6 py-14 text-center">
                    <ReceiptText
                        className="mx-auto size-9 text-muted-foreground/60"
                        aria-hidden
                    />
                    <p className="mt-3 font-medium">
                        {t('fundraising.no_donations')}
                    </p>
                </div>
            ) : (
                <DonationRows
                    donations={donations.data}
                    mosqueSlug={mosque.slug}
                />
            )}

            <Pager page={donations} />
            <p className="text-sm text-muted-foreground">
                {t('fundraising.donations_receipts_note')}
            </p>
        </ManageLayout>
    );
}
