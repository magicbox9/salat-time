import { Head, Link } from '@inertiajs/react';
import { Inbox } from 'lucide-react';
import { AdminShell } from '@/components/admin/admin-shell';
import { ClaimsList } from '@/components/admin/claim-rows';
import { EmptyState } from '@/components/admin/empty-state';
import { SearchField, useApplyFilters } from '@/components/admin/filters';
import { Pagination } from '@/components/admin/pagination';
import type { AdminPageProps, Paginated } from '@/components/admin/types';
import type { AdminClaimRow, ClaimStatus } from '@/components/claims/types';
import { useT } from '@/lib/i18n';
import { cn } from '@/lib/utils';

type StatusFilter = ClaimStatus | 'all';

type Props = AdminPageProps & {
    claims: Paginated<AdminClaimRow>;
    filters: { status: StatusFilter; q: string | null };
    counts: Record<StatusFilter, number>;
};

const TABS: StatusFilter[] = ['pending', 'approved', 'rejected', 'all'];

/** /admin/claims — the review queue. */
export default function AdminClaims({
    claims,
    filters,
    counts,
    pendingClaimsCount,
}: Props) {
    const t = useT();
    const apply = useApplyFilters('/admin/claims', filters);

    return (
        <>
            <Head title={t('admin.claims_title')} />
            <AdminShell
                title={t('admin.claims_title')}
                description={t('admin.claims_intro')}
                pendingClaimsCount={pendingClaimsCount}
            >
                <div className="flex flex-col gap-3 lg:flex-row lg:items-center lg:justify-between">
                    <div className="-mx-4 overflow-x-auto px-4">
                        <nav
                            className="flex w-max gap-1"
                            aria-label={t('admin.col_status')}
                        >
                            {TABS.map((status) => {
                                const active = filters.status === status;

                                return (
                                    <Link
                                        key={status}
                                        href="/admin/claims"
                                        data={{
                                            status,
                                            ...(filters.q
                                                ? { q: filters.q }
                                                : {}),
                                        }}
                                        preserveState
                                        aria-current={
                                            active ? 'page' : undefined
                                        }
                                        className={cn(
                                            'inline-flex items-center gap-2 rounded-full border px-3 py-1.5 text-sm font-medium whitespace-nowrap transition-colors',
                                            active
                                                ? 'border-primary bg-primary text-primary-foreground'
                                                : 'text-muted-foreground hover:border-primary/40 hover:text-foreground',
                                        )}
                                    >
                                        {t(
                                            status === 'all'
                                                ? 'admin.filter_all'
                                                : `claims.status_${status}`,
                                        )}
                                        <span
                                            className="text-xs tabular-nums opacity-80"
                                            dir="ltr"
                                        >
                                            {counts[status]}
                                        </span>
                                    </Link>
                                );
                            })}
                        </nav>
                    </div>
                    <SearchField
                        value={filters.q}
                        placeholder={t('admin.claims_search')}
                        onSearch={(q) => apply({ q })}
                    />
                </div>

                {claims.data.length === 0 ? (
                    <EmptyState
                        icon={Inbox}
                        title={
                            filters.q
                                ? t('admin.no_results')
                                : t(`admin.claims_empty_${filters.status}`)
                        }
                    />
                ) : (
                    <ClaimsList claims={claims.data} />
                )}

                <Pagination page={claims} />
            </AdminShell>
        </>
    );
}
