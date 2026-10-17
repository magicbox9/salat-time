import { Head, Link } from '@inertiajs/react';
import {
    ChevronRight,
    HandCoins,
    HeartHandshake,
    Landmark,
} from 'lucide-react';
import { useFormatDate } from '@/components/claims/use-format-date';
import { DonationStatusBadge } from '@/components/fundraising/badges';
import { CampaignCover } from '@/components/fundraising/campaign-cover';
import { useCount, useMoney } from '@/components/fundraising/format';
import type {
    DonationMethod,
    DonationStatus,
} from '@/components/fundraising/types';
import { Pager } from '@/components/manage/pager';
import type { Paginated } from '@/components/manage/pager';
import { Button } from '@/components/ui/button';
import { useT } from '@/lib/i18n';

type MyDonation = {
    reference: string;
    amount: number;
    currency: string;
    method: DonationMethod;
    status: DonationStatus;
    anonymous: boolean;
    created_at: string | null;
    campaign: {
        slug: string;
        title: string;
        cover_url: string | null;
        visible: boolean;
    } | null;
    mosque: { slug: string; name: string; city: string | null } | null;
    receipt_url: string;
};

type Props = {
    donations: Paginated<MyDonation>;
    totals: { amount: number; count: number; currency: string };
};

/** /me/donations — what I gave, to whom, and where each gift stands. */
export default function MyDonations({ donations, totals }: Props) {
    const t = useT();
    const money = useMoney();
    const count = useCount();
    const formatDate = useFormatDate();

    return (
        <>
            <Head title={t('fundraising.my_title')} />
            <div className="mx-auto max-w-3xl space-y-6">
                <header className="space-y-1">
                    <h1 className="text-2xl font-semibold tracking-tight">
                        {t('fundraising.my_title')}
                    </h1>
                    <p className="text-muted-foreground">
                        {t('fundraising.my_intro')}
                    </p>
                </header>

                {totals.count > 0 && (
                    <div className="flex items-center gap-4 rounded-3xl border bg-card p-5 shadow-xs">
                        <span className="flex size-12 shrink-0 items-center justify-center rounded-2xl bg-gold/20 text-amber-700 dark:text-gold">
                            <HeartHandshake className="size-6" aria-hidden />
                        </span>
                        <div>
                            <p
                                className="text-2xl font-semibold tabular-nums"
                                dir="ltr"
                            >
                                <span className="inline-block">
                                    {money(totals.amount, totals.currency)}
                                </span>
                            </p>
                            <p className="text-sm text-muted-foreground">
                                {t('fundraising.my_total', {
                                    count: count(totals.count),
                                })}
                            </p>
                        </div>
                    </div>
                )}

                {donations.data.length === 0 ? (
                    <div className="rounded-3xl border border-dashed px-6 py-14 text-center">
                        <HandCoins
                            className="mx-auto size-10 text-gold"
                            aria-hidden
                        />
                        <p className="mt-4 font-medium">
                            {t('fundraising.my_empty')}
                        </p>
                        <Button asChild className="mt-5">
                            <Link href="/campaigns">
                                {t('fundraising.see_every_campaign')}
                            </Link>
                        </Button>
                    </div>
                ) : (
                    <ul className="divide-y overflow-hidden rounded-3xl border bg-card shadow-xs">
                        {donations.data.map((donation) => (
                            <li key={donation.reference}>
                                <Link
                                    href={donation.receipt_url}
                                    className="flex items-center gap-4 p-4 transition-colors hover:bg-muted/50 focus-visible:bg-muted/50 focus-visible:outline-none"
                                >
                                    <CampaignCover
                                        url={
                                            donation.campaign?.cover_url ?? null
                                        }
                                        className="hidden size-14 shrink-0 rounded-xl sm:block"
                                    />
                                    <div className="min-w-0 flex-1 space-y-1">
                                        <p className="truncate font-medium">
                                            {donation.campaign?.title ?? '—'}
                                        </p>
                                        <p className="truncate text-sm text-muted-foreground">
                                            {[
                                                donation.mosque?.name,
                                                formatDate(donation.created_at),
                                            ]
                                                .filter(Boolean)
                                                .join(' · ')}
                                        </p>
                                        <div className="flex flex-wrap items-center gap-2 text-xs text-muted-foreground">
                                            <DonationStatusBadge
                                                status={donation.status}
                                            />
                                            <span className="inline-flex items-center gap-1">
                                                {donation.method === 'bank' && (
                                                    <Landmark
                                                        className="size-3.5"
                                                        aria-hidden
                                                    />
                                                )}
                                                {t(
                                                    `fundraising.method_${donation.method}`,
                                                )}
                                            </span>
                                            <span
                                                className="font-mono"
                                                dir="ltr"
                                            >
                                                {donation.reference}
                                            </span>
                                        </div>
                                    </div>
                                    <p
                                        className="shrink-0 text-end font-semibold"
                                        dir="ltr"
                                    >
                                        {money(
                                            donation.amount,
                                            donation.currency,
                                        )}
                                    </p>
                                    <ChevronRight
                                        className="size-4 shrink-0 text-muted-foreground rtl:rotate-180"
                                        aria-hidden
                                    />
                                </Link>
                            </li>
                        ))}
                    </ul>
                )}

                <Pager page={donations} />
                <p className="text-sm text-muted-foreground">
                    {t('fundraising.tax_receipt_note')}
                </p>
            </div>
        </>
    );
}
