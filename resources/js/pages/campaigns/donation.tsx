import { Head, Link } from '@inertiajs/react';
import {
    ArrowRight,
    CheckCircle2,
    Clock,
    Info,
    Landmark,
    XCircle,
} from 'lucide-react';
import { CampaignCover } from '@/components/fundraising/campaign-cover';
import { CopyField } from '@/components/fundraising/copy-field';
import { useMoney } from '@/components/fundraising/format';
import type {
    BankTransfer,
    CampaignCardData,
    DonationMethod,
    DonationStatus,
} from '@/components/fundraising/types';
import { Button } from '@/components/ui/button';
import { useT } from '@/lib/i18n';

type Props = {
    donation: {
        reference: string;
        amount: number;
        currency: string;
        method: DonationMethod;
        status: DonationStatus;
        anonymous: boolean;
        donor_name: string | null;
        created_at: string | null;
    };
    campaign: CampaignCardData;
    bank: BankTransfer | null;
};

/** The donor's page for one donation: thanks, where it stands, and the transfer details for a bank pledge. */
export default function DonationReceipt({ donation, campaign, bank }: Props) {
    const t = useT();
    const money = useMoney();
    const amount = money(donation.amount, donation.currency);
    const pendingBank =
        donation.method === 'bank' && donation.status === 'pending';
    const done = donation.status === 'completed';
    const failed = ['cancelled', 'failed', 'refunded'].includes(
        donation.status,
    );
    const Icon = done ? CheckCircle2 : failed ? XCircle : Clock;
    const firstName = donation.donor_name?.split(/\s+/)[0] ?? '';

    return (
        <>
            <Head title={t('fundraising.receipt_title')}>
                <meta name="robots" content="noindex" />
            </Head>
            <div className="mx-auto max-w-2xl space-y-6">
                <section className="overflow-hidden rounded-3xl border bg-card shadow-sm">
                    <CampaignCover
                        url={campaign.cover_url}
                        className="h-28 sm:h-36"
                    />
                    <div className="space-y-4 p-6 sm:p-8">
                        <span
                            className={
                                done
                                    ? 'inline-flex size-12 items-center justify-center rounded-full bg-emerald-500/15 text-emerald-700 dark:text-emerald-300'
                                    : failed
                                      ? 'inline-flex size-12 items-center justify-center rounded-full bg-muted text-muted-foreground'
                                      : 'inline-flex size-12 items-center justify-center rounded-full bg-gold/20 text-amber-700 dark:text-gold'
                            }
                        >
                            <Icon className="size-6" aria-hidden />
                        </span>
                        <div className="space-y-2">
                            <h1 className="text-2xl font-semibold tracking-tight text-balance sm:text-3xl">
                                {failed
                                    ? t('fundraising.receipt_failed_title')
                                    : firstName
                                      ? t('fundraising.receipt_thanks_name', {
                                            name: firstName,
                                        })
                                      : t('fundraising.receipt_thanks')}
                            </h1>
                            <p className="text-muted-foreground">
                                {t(
                                    `fundraising.receipt_${pendingBank ? 'bank_pending' : donation.method === 'paypal' && donation.status === 'pending' ? 'paypal_pending' : donation.status}`,
                                    {
                                        amount,
                                        campaign: campaign.title,
                                        mosque: campaign.mosque?.name ?? '',
                                    },
                                )}
                            </p>
                        </div>
                        <dl className="grid gap-3 rounded-2xl bg-muted/50 p-4 text-sm sm:grid-cols-2">
                            <div>
                                <dt className="text-xs text-muted-foreground">
                                    {t('fundraising.amount')}
                                </dt>
                                <dd className="text-lg font-semibold" dir="ltr">
                                    <span className="inline-block">
                                        {amount}
                                    </span>
                                </dd>
                            </div>
                            <div>
                                <dt className="text-xs text-muted-foreground">
                                    {t('fundraising.reference')}
                                </dt>
                                <dd
                                    className="font-mono text-lg font-semibold"
                                    dir="ltr"
                                >
                                    <span className="inline-block">
                                        {donation.reference}
                                    </span>
                                </dd>
                            </div>
                        </dl>
                    </div>
                </section>

                {pendingBank && (
                    <section
                        aria-labelledby="bank-title"
                        className="rounded-3xl border border-gold/40 bg-card p-6 shadow-sm sm:p-8"
                    >
                        <h2
                            id="bank-title"
                            className="flex items-center gap-2 text-lg font-semibold"
                        >
                            <Landmark
                                className="size-5 text-gold"
                                aria-hidden
                            />
                            {t('fundraising.bank_title')}
                        </h2>
                        <p className="mt-1 text-sm text-muted-foreground">
                            {t('fundraising.bank_intro')}
                        </p>
                        {bank ? (
                            <dl className="mt-5 grid gap-4">
                                {bank.account_holder && (
                                    <CopyField
                                        label={t(
                                            'fundraising.field_account_holder',
                                        )}
                                        value={bank.account_holder}
                                    />
                                )}
                                <CopyField
                                    label="IBAN"
                                    value={bank.iban}
                                    copyValue={bank.iban.replace(/\s/g, '')}
                                />
                                {bank.bic && (
                                    <CopyField label="BIC" value={bank.bic} />
                                )}
                                {bank.bank_name && (
                                    <CopyField
                                        label={t('fundraising.field_bank_name')}
                                        value={bank.bank_name}
                                    />
                                )}
                                <div className="grid gap-4 sm:grid-cols-2">
                                    <CopyField
                                        label={t('fundraising.amount')}
                                        value={amount}
                                        copyValue={(
                                            donation.amount / 100
                                        ).toFixed(2)}
                                        emphasis
                                    />
                                    <CopyField
                                        label={t(
                                            'fundraising.transfer_reference',
                                        )}
                                        value={donation.reference}
                                        emphasis
                                    />
                                </div>
                            </dl>
                        ) : (
                            <p className="mt-5 rounded-xl bg-amber-500/10 px-4 py-3 text-sm">
                                {t('fundraising.bank_unavailable')}
                            </p>
                        )}
                        <ul className="mt-5 space-y-2 text-sm text-muted-foreground">
                            <li className="flex items-start gap-2">
                                <Info
                                    className="mt-0.5 size-4 shrink-0 text-primary"
                                    aria-hidden
                                />
                                {t('fundraising.bank_reference_hint')}
                            </li>
                            <li className="flex items-start gap-2">
                                <Info
                                    className="mt-0.5 size-4 shrink-0 text-primary"
                                    aria-hidden
                                />
                                {t('fundraising.bank_sepa_hint')}
                            </li>
                            <li className="flex items-start gap-2">
                                <Info
                                    className="mt-0.5 size-4 shrink-0 text-primary"
                                    aria-hidden
                                />
                                {t('fundraising.bank_confirm_hint')}
                            </li>
                        </ul>
                    </section>
                )}

                <p className="rounded-2xl bg-muted/50 p-4 text-sm text-muted-foreground">
                    {t('fundraising.tax_receipt_note')}
                </p>

                <div className="flex flex-col gap-2 sm:flex-row sm:justify-between">
                    <Button asChild variant="outline">
                        <Link href={`/campaigns/${campaign.slug}`}>
                            {t('fundraising.back_to_campaign')}
                            <ArrowRight
                                className="size-4 rtl:rotate-180"
                                aria-hidden
                            />
                        </Link>
                    </Button>
                    <Button asChild variant="ghost">
                        <Link href="/campaigns">
                            {t('fundraising.all_campaigns')}
                        </Link>
                    </Button>
                </div>
            </div>
        </>
    );
}
