import { CreditCard, Info, Landmark, ShieldCheck } from 'lucide-react';
import type { LucideIcon } from 'lucide-react';
import type { ReactNode } from 'react';
import { FundraisingNav } from '@/components/fundraising/manage-nav';
import {
    BankForm,
    PayoutStatus,
    PayPalForm,
} from '@/components/fundraising/payout-forms';
import type { PayoutMethod } from '@/components/fundraising/types';
import { ConfirmDelete } from '@/components/manage/confirm-delete';
import { ManageLayout } from '@/components/manage/manage-layout';
import { useT } from '@/lib/i18n';
import type { MosqueSummary } from '@/types/mosque';

type Props = {
    mosque: MosqueSummary;
    paypal: PayoutMethod | null;
    bank: PayoutMethod | null;
    paypalEnabled: boolean;
    mosqueVerified: boolean;
};

/** /manage/{mosque}/payouts — the mosque's own accounts, where donations go directly. */
export default function ManagePayouts({
    mosque,
    paypal,
    bank,
    paypalEnabled,
    mosqueVerified,
}: Props) {
    const t = useT();
    const url = `/manage/${mosque.slug}/payouts`;

    return (
        <ManageLayout
            mosque={mosque}
            title={t('fundraising.payouts_title')}
            description={t('fundraising.payouts_intro')}
        >
            <FundraisingNav mosqueSlug={mosque.slug} />

            <div className="flex items-start gap-3 rounded-2xl bg-primary/5 p-4 text-sm">
                <ShieldCheck
                    className="mt-0.5 size-5 shrink-0 text-primary"
                    aria-hidden
                />
                <div className="space-y-1">
                    <p className="font-medium">
                        {t('fundraising.payouts_direct_title')}
                    </p>
                    <p className="text-muted-foreground">
                        {t('fundraising.payouts_direct_body')}
                    </p>
                </div>
            </div>

            {!mosqueVerified && (
                <p className="flex items-start gap-2 rounded-2xl border border-amber-500/40 bg-amber-500/10 p-4 text-sm">
                    <Info className="mt-0.5 size-4 shrink-0" aria-hidden />
                    {t('fundraising.problem_mosque_unverified_help')}
                </p>
            )}

            <PayoutCard
                icon={CreditCard}
                title={t('fundraising.method_paypal')}
                description={
                    paypalEnabled
                        ? t('fundraising.payouts_paypal_intro')
                        : t('fundraising.paypal_platform_off')
                }
                payout={paypal}
                remove={
                    paypal && (
                        <ConfirmDelete
                            url={`${url}/paypal`}
                            title={t('fundraising.payout_delete_title')}
                            description={t('fundraising.payout_delete_body')}
                            iconOnly
                        />
                    )
                }
            >
                <PayPalForm url={url} payout={paypal} />
            </PayoutCard>

            <PayoutCard
                icon={Landmark}
                title={t('fundraising.method_bank')}
                description={t('fundraising.payouts_bank_intro')}
                payout={bank}
                remove={
                    bank && (
                        <ConfirmDelete
                            url={`${url}/bank`}
                            title={t('fundraising.payout_delete_title')}
                            description={t('fundraising.payout_delete_body')}
                            iconOnly
                        />
                    )
                }
            >
                <BankForm url={url} payout={bank} />
            </PayoutCard>

            <p className="text-sm text-muted-foreground">
                {t('fundraising.payouts_review_note')}
            </p>
        </ManageLayout>
    );
}

function PayoutCard({
    icon: Icon,
    title,
    description,
    payout,
    remove,
    children,
}: {
    icon: LucideIcon;
    title: string;
    description: string;
    payout: PayoutMethod | null;
    remove: ReactNode;
    children: ReactNode;
}) {
    return (
        <section className="rounded-3xl border bg-card p-5 shadow-xs sm:p-6">
            <div className="flex items-start justify-between gap-3">
                <div className="flex min-w-0 items-start gap-3">
                    <span className="flex size-10 shrink-0 items-center justify-center rounded-xl bg-primary/10 text-primary">
                        <Icon className="size-5" aria-hidden />
                    </span>
                    <div className="min-w-0 space-y-1">
                        <h2 className="font-semibold">{title}</h2>
                        <p className="text-sm text-muted-foreground">
                            {description}
                        </p>
                        <PayoutStatus payout={payout} />
                    </div>
                </div>
                {remove}
            </div>
            <div className="mt-5">{children}</div>
        </section>
    );
}
