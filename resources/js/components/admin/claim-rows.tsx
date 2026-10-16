import { Link } from '@inertiajs/react';
import { ChevronRight, Paperclip } from 'lucide-react';
import { ClaimStatusBadge } from '@/components/claims/claim-status-badge';
import type { AdminClaimRow } from '@/components/claims/types';
import { useFormatDate } from '@/components/claims/use-format-date';
import { Button } from '@/components/ui/button';
import { useT } from '@/lib/i18n';

/** A pending request in the overview list. */
export function ClaimRowCompact({ claim }: { claim: AdminClaimRow }) {
    const t = useT();
    const formatDate = useFormatDate();

    return (
        <li>
            <Link
                href={`/admin/claims/${claim.id}`}
                className="flex items-center gap-4 px-5 py-3.5 transition-colors hover:bg-muted/50"
            >
                <div className="min-w-0 flex-1">
                    <p className="truncate font-medium">
                        {claim.mosque?.name ?? '—'}
                    </p>
                    <p className="truncate text-sm text-muted-foreground">
                        {t('admin.claim_by', {
                            name: claim.user?.name ?? '—',
                            role: claim.role_at_mosque,
                        })}
                    </p>
                </div>
                <span className="hidden text-sm text-muted-foreground sm:inline">
                    {formatDate(claim.created_at)}
                </span>
                <ChevronRight
                    className="size-4 shrink-0 text-muted-foreground rtl:rotate-180"
                    aria-hidden
                />
            </Link>
        </li>
    );
}

/** The review queue: a table from tablets up, cards on phones. */
export function ClaimsList({ claims }: { claims: AdminClaimRow[] }) {
    const t = useT();
    const formatDate = useFormatDate();

    return (
        <>
            <div className="hidden overflow-hidden rounded-xl border bg-card shadow-sm md:block">
                <table className="w-full text-sm">
                    <thead className="bg-muted/50 text-xs text-muted-foreground">
                        <tr>
                            <th className="px-4 py-3 text-start font-medium">
                                {t('admin.col_mosque')}
                            </th>
                            <th className="px-4 py-3 text-start font-medium">
                                {t('admin.col_claimant')}
                            </th>
                            <th className="px-4 py-3 text-start font-medium">
                                {t('admin.col_submitted')}
                            </th>
                            <th className="px-4 py-3 text-start font-medium">
                                {t('admin.col_status')}
                            </th>
                            <th className="px-4 py-3">
                                <span className="sr-only">
                                    {t('admin.col_actions')}
                                </span>
                            </th>
                        </tr>
                    </thead>
                    <tbody className="divide-y">
                        {claims.map((claim) => (
                            <tr
                                key={claim.id}
                                className="align-top transition-colors hover:bg-muted/30"
                            >
                                <td className="px-4 py-3">
                                    <p className="font-medium">
                                        {claim.mosque?.name ?? '—'}
                                    </p>
                                    <p className="text-xs text-muted-foreground">
                                        {claim.mosque?.city}
                                    </p>
                                </td>
                                <td className="px-4 py-3">
                                    <p className="font-medium">
                                        {claim.user?.name ?? '—'}
                                    </p>
                                    <p className="text-xs text-muted-foreground">
                                        <span dir="ltr">
                                            {claim.user?.email}
                                        </span>
                                    </p>
                                    <p className="mt-1 text-xs">
                                        {claim.role_at_mosque}
                                    </p>
                                </td>
                                <td className="px-4 py-3 whitespace-nowrap text-muted-foreground">
                                    {formatDate(claim.created_at)}
                                </td>
                                <td className="px-4 py-3">
                                    <div className="flex items-center gap-2">
                                        <ClaimStatusBadge
                                            status={claim.status}
                                        />
                                        {claim.has_document && (
                                            <Paperclip
                                                role="img"
                                                className="size-4 text-muted-foreground"
                                                aria-label={t(
                                                    'admin.has_document',
                                                )}
                                            />
                                        )}
                                    </div>
                                </td>
                                <td className="px-4 py-3 text-end">
                                    <Button
                                        asChild
                                        size="sm"
                                        variant={
                                            claim.status === 'pending'
                                                ? 'default'
                                                : 'outline'
                                        }
                                    >
                                        <Link
                                            href={`/admin/claims/${claim.id}`}
                                        >
                                            {claim.status === 'pending'
                                                ? t('admin.review')
                                                : t('admin.open')}
                                        </Link>
                                    </Button>
                                </td>
                            </tr>
                        ))}
                    </tbody>
                </table>
            </div>

            <ul className="grid gap-3 md:hidden">
                {claims.map((claim) => (
                    <li key={claim.id}>
                        <Link
                            href={`/admin/claims/${claim.id}`}
                            className="block rounded-xl border bg-card p-4 shadow-sm transition-colors hover:border-primary/40"
                        >
                            <div className="flex items-start justify-between gap-3">
                                <div className="min-w-0">
                                    <p className="truncate font-medium">
                                        {claim.mosque?.name ?? '—'}
                                    </p>
                                    <p className="text-xs text-muted-foreground">
                                        {claim.mosque?.city}
                                    </p>
                                </div>
                                <ClaimStatusBadge status={claim.status} />
                            </div>
                            <p className="mt-3 text-sm">
                                {t('admin.claim_by', {
                                    name: claim.user?.name ?? '—',
                                    role: claim.role_at_mosque,
                                })}
                            </p>
                            <div className="mt-2 flex items-center gap-2 text-xs text-muted-foreground">
                                {formatDate(claim.created_at)}
                                {claim.has_document && (
                                    <Paperclip
                                        role="img"
                                        className="size-3.5"
                                        aria-label={t('admin.has_document')}
                                    />
                                )}
                            </div>
                        </Link>
                    </li>
                ))}
            </ul>
        </>
    );
}
