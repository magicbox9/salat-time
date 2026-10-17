import { Check, Landmark, X } from 'lucide-react';
import { ConfirmAction } from '@/components/admin/confirm-action';
import { useFormatDate } from '@/components/claims/use-format-date';
import { Button } from '@/components/ui/button';
import { useT } from '@/lib/i18n';
import { DonationStatusBadge } from './badges';
import { useMoney } from './format';
import type { ManagedDonation } from './types';

/**
 * Donations as the mosque sees them, with the confirm / cancel actions of a
 * bank transfer (each asks first).
 */
export function DonationRows({
    donations,
    mosqueSlug,
    showCampaign = true,
}: {
    donations: ManagedDonation[];
    mosqueSlug: string;
    showCampaign?: boolean;
}) {
    const t = useT();
    const money = useMoney();
    const formatDate = useFormatDate();

    return (
        <ul className="divide-y overflow-hidden rounded-2xl border bg-card shadow-xs">
            {donations.map((donation) => (
                <li
                    key={donation.id}
                    className="flex flex-col gap-3 p-4 sm:flex-row sm:items-center"
                >
                    <div className="min-w-0 flex-1 space-y-1">
                        <div className="flex flex-wrap items-center gap-2">
                            <span className="font-semibold" dir="ltr">
                                {money(donation.amount, donation.currency)}
                            </span>
                            <DonationStatusBadge status={donation.status} />
                            <span className="inline-flex items-center gap-1 text-xs text-muted-foreground">
                                {donation.method === 'bank' && (
                                    <Landmark
                                        className="size-3.5"
                                        aria-hidden
                                    />
                                )}
                                {t(`fundraising.method_${donation.method}`)}
                            </span>
                            {donation.anonymous && (
                                <span className="rounded-full bg-muted px-2 py-0.5 text-xs text-muted-foreground">
                                    {t('fundraising.anonymous_short')}
                                </span>
                            )}
                        </div>
                        <p className="truncate text-sm">
                            {donation.donor_name ?? '—'}
                            {donation.donor_email && (
                                <a
                                    href={`mailto:${donation.donor_email}`}
                                    className="ms-2 text-muted-foreground hover:underline"
                                    dir="ltr"
                                >
                                    {donation.donor_email}
                                </a>
                            )}
                        </p>
                        <p className="flex flex-wrap gap-x-3 text-xs text-muted-foreground">
                            <span className="font-mono" dir="ltr">
                                {donation.reference}
                            </span>
                            <span>
                                {formatDate(donation.created_at, 'datetime')}
                            </span>
                            {showCampaign && donation.campaign && (
                                <span className="truncate">
                                    {donation.campaign.title}
                                </span>
                            )}
                        </p>
                        {donation.message && (
                            <p className="text-sm break-words text-muted-foreground italic">
                                “{donation.message}”
                            </p>
                        )}
                    </div>
                    {donation.can_confirm && (
                        <div className="flex shrink-0 gap-2">
                            <ConfirmAction
                                trigger={
                                    <Button size="sm">
                                        <Check className="size-4" aria-hidden />
                                        {t('fundraising.confirm_received')}
                                    </Button>
                                }
                                title={t('fundraising.confirm_title')}
                                description={t('fundraising.confirm_body', {
                                    amount: money(
                                        donation.amount,
                                        donation.currency,
                                    ),
                                    reference: donation.reference,
                                })}
                                confirmLabel={t('fundraising.confirm_received')}
                                method="post"
                                url={`/manage/${mosqueSlug}/donations/${donation.id}/confirm`}
                            />
                            <ConfirmAction
                                trigger={
                                    <Button
                                        size="sm"
                                        variant="ghost"
                                        className="text-muted-foreground hover:text-destructive"
                                    >
                                        <X className="size-4" aria-hidden />
                                        {t('fundraising.cancel_pledge')}
                                    </Button>
                                }
                                title={t('fundraising.cancel_title')}
                                description={t('fundraising.cancel_body', {
                                    reference: donation.reference,
                                })}
                                confirmLabel={t('fundraising.cancel_pledge')}
                                method="post"
                                url={`/manage/${mosqueSlug}/donations/${donation.id}/cancel`}
                                destructive
                            />
                        </div>
                    )}
                </li>
            ))}
        </ul>
    );
}
