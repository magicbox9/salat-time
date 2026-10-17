import { Head, Link } from '@inertiajs/react';
import { BadgeCheck, CreditCard, Landmark, Undo2 } from 'lucide-react';
import { AdminShell } from '@/components/admin/admin-shell';
import { ConfirmAction } from '@/components/admin/confirm-action';
import { EmptyState } from '@/components/admin/empty-state';
import { useApplyFilters } from '@/components/admin/filters';
import { Pagination } from '@/components/admin/pagination';
import type { AdminPageProps, Paginated } from '@/components/admin/types';
import { AdminFundraisingNav } from '@/components/fundraising/admin-nav';
import { PayoutStatus } from '@/components/fundraising/payout-forms';
import { RevealIban } from '@/components/fundraising/reveal-iban';
import type { AdminPayoutRow } from '@/components/fundraising/types';
import { Button } from '@/components/ui/button';
import { useT } from '@/lib/i18n';
import { cn } from '@/lib/utils';

type State = 'to_verify' | 'verified' | 'all';

type Props = AdminPageProps & {
    payouts: Paginated<AdminPayoutRow>;
    state: State;
};

/** /admin/fundraising/payouts — the accounts donations go to, verified one by one. */
export default function AdminPayouts({
    payouts,
    state,
    pendingClaimsCount,
}: Props) {
    const t = useT();
    const apply = useApplyFilters('/admin/fundraising/payouts', { state });

    return (
        <>
            <Head title={t('fundraising.admin_payouts')} />
            <AdminShell
                title={t('fundraising.admin_payouts')}
                description={t('fundraising.admin_payouts_page_intro')}
                pendingClaimsCount={pendingClaimsCount}
            >
                <AdminFundraisingNav />

                <div className="flex w-max gap-1 rounded-xl bg-muted p-1">
                    {(['to_verify', 'verified', 'all'] as State[]).map(
                        (filter) => (
                            <button
                                key={filter}
                                type="button"
                                aria-pressed={filter === state}
                                onClick={() => apply({ state: filter })}
                                className={cn(
                                    'rounded-lg px-3 py-1.5 text-sm font-medium whitespace-nowrap transition-colors',
                                    filter === state
                                        ? 'bg-background shadow-sm'
                                        : 'text-muted-foreground hover:text-foreground',
                                )}
                            >
                                {t(`fundraising.admin_filter_${filter}`)}
                            </button>
                        ),
                    )}
                </div>

                {payouts.data.length === 0 ? (
                    <EmptyState
                        icon={BadgeCheck}
                        title={t('fundraising.admin_nothing_to_verify')}
                    />
                ) : (
                    <ul className="grid gap-4">
                        {payouts.data.map((payout) => (
                            <li
                                key={payout.id}
                                className="rounded-xl border bg-card p-5 shadow-sm"
                            >
                                <div className="flex flex-wrap items-start justify-between gap-3">
                                    <div className="flex min-w-0 items-start gap-3">
                                        <span className="flex size-10 shrink-0 items-center justify-center rounded-xl bg-primary/10 text-primary">
                                            {payout.type === 'paypal' ? (
                                                <CreditCard
                                                    className="size-5"
                                                    aria-hidden
                                                />
                                            ) : (
                                                <Landmark
                                                    className="size-5"
                                                    aria-hidden
                                                />
                                            )}
                                        </span>
                                        <div className="min-w-0">
                                            <p className="font-semibold">
                                                {t(
                                                    `fundraising.method_${payout.type}`,
                                                )}
                                            </p>
                                            {payout.mosque && (
                                                <Link
                                                    href={`/admin/mosques/${payout.mosque.slug}`}
                                                    className="text-sm text-muted-foreground hover:underline"
                                                >
                                                    {payout.mosque.name}
                                                    {payout.mosque.city
                                                        ? ` · ${payout.mosque.city}`
                                                        : ''}
                                                    {!payout.mosque.verified &&
                                                        ` · ${t('fundraising.admin_mosque_unverified')}`}
                                                </Link>
                                            )}
                                        </div>
                                    </div>
                                    <PayoutStatus payout={payout} />
                                </div>

                                <dl className="mt-4 grid gap-3 text-sm sm:grid-cols-2">
                                    {payout.type === 'paypal' ? (
                                        <>
                                            <Detail
                                                label={t(
                                                    'fundraising.field_paypal_email',
                                                )}
                                                value={payout.paypal_email}
                                            />
                                            <Detail
                                                label={t(
                                                    'fundraising.field_merchant_id',
                                                )}
                                                value={
                                                    payout.paypal_merchant_id
                                                }
                                            />
                                        </>
                                    ) : (
                                        <>
                                            <Detail
                                                label={t(
                                                    'fundraising.field_account_holder',
                                                )}
                                                value={payout.account_holder}
                                            />
                                            <div>
                                                <dt className="text-xs text-muted-foreground">
                                                    IBAN
                                                </dt>
                                                <dd className="mt-0.5">
                                                    <RevealIban
                                                        key={payout.version}
                                                        payoutId={payout.id}
                                                        masked={
                                                            payout.iban_masked ??
                                                            '—'
                                                        }
                                                    />
                                                </dd>
                                            </div>
                                            <Detail
                                                label="BIC"
                                                value={payout.bic}
                                            />
                                            <Detail
                                                label={t(
                                                    'fundraising.field_bank_name',
                                                )}
                                                value={payout.bank_name}
                                            />
                                        </>
                                    )}
                                    {payout.verified_by && (
                                        <Detail
                                            label={t(
                                                'fundraising.admin_verified_by',
                                            )}
                                            value={payout.verified_by}
                                        />
                                    )}
                                </dl>

                                <div className="mt-4 flex flex-wrap gap-2">
                                    {payout.verified ? (
                                        <ConfirmAction
                                            trigger={
                                                <Button
                                                    variant="outline"
                                                    size="sm"
                                                >
                                                    <Undo2
                                                        className="size-4"
                                                        aria-hidden
                                                    />
                                                    {t(
                                                        'fundraising.admin_unverify',
                                                    )}
                                                </Button>
                                            }
                                            title={t(
                                                'fundraising.admin_unverify_title',
                                            )}
                                            description={t(
                                                'fundraising.admin_unverify_body',
                                            )}
                                            confirmLabel={t(
                                                'fundraising.admin_unverify',
                                            )}
                                            method="delete"
                                            url={`/admin/fundraising/payouts/${payout.id}/verify`}
                                            destructive
                                        />
                                    ) : (
                                        <ConfirmAction
                                            trigger={
                                                <Button size="sm">
                                                    <BadgeCheck
                                                        className="size-4"
                                                        aria-hidden
                                                    />
                                                    {t(
                                                        'fundraising.admin_verify',
                                                    )}
                                                </Button>
                                            }
                                            title={t(
                                                'fundraising.admin_verify_title',
                                            )}
                                            description={t(
                                                'fundraising.admin_verify_body',
                                            )}
                                            confirmLabel={t(
                                                'fundraising.admin_verify',
                                            )}
                                            method="post"
                                            url={`/admin/fundraising/payouts/${payout.id}/verify?version=${encodeURIComponent(payout.version)}`}
                                        />
                                    )}
                                </div>
                            </li>
                        ))}
                    </ul>
                )}

                <Pagination page={payouts} />
            </AdminShell>
        </>
    );
}

function Detail({ label, value }: { label: string; value: string | null }) {
    return (
        <div className="min-w-0">
            <dt className="text-xs text-muted-foreground">{label}</dt>
            <dd className="mt-0.5 break-all" dir="auto">
                {value || '—'}
            </dd>
        </div>
    );
}
