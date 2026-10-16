import { Link } from '@inertiajs/react';
import { Building2, Download, RotateCcw } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { useT } from '@/lib/i18n';
import { ClaimStatusBadge } from './claim-status-badge';
import type { ClaimantClaim } from './types';
import { useFormatDate } from './use-format-date';

/** One of the signed-in user's requests (/me/claims). */
export function ClaimCard({ claim }: { claim: ClaimantClaim }) {
    const t = useT();
    const formatDate = useFormatDate();
    const mosque = claim.mosque;

    return (
        <article className="rounded-xl border bg-card p-5 shadow-sm sm:p-6">
            <div className="flex flex-wrap items-start justify-between gap-3">
                <div className="min-w-0">
                    {mosque ? (
                        <Link
                            href={`/mosques/${mosque.slug}`}
                            className="font-semibold underline-offset-4 hover:underline"
                        >
                            {mosque.name}
                        </Link>
                    ) : (
                        <span className="font-semibold">—</span>
                    )}
                    {mosque?.city && (
                        <p className="text-sm text-muted-foreground">
                            {mosque.city}
                        </p>
                    )}
                </div>
                <ClaimStatusBadge status={claim.status} />
            </div>

            <dl className="mt-4 grid gap-3 text-sm sm:grid-cols-3">
                <div>
                    <dt className="text-xs text-muted-foreground">
                        {t('claims.field_role')}
                    </dt>
                    <dd className="mt-0.5 font-medium break-words">
                        {claim.role_at_mosque}
                    </dd>
                </div>
                <div>
                    <dt className="text-xs text-muted-foreground">
                        {t('claims.submitted_on')}
                    </dt>
                    <dd className="mt-0.5">{formatDate(claim.created_at)}</dd>
                </div>
                <div>
                    <dt className="text-xs text-muted-foreground">
                        {t('claims.reviewed_on')}
                    </dt>
                    <dd className="mt-0.5">
                        {claim.reviewed_at
                            ? formatDate(claim.reviewed_at)
                            : t('claims.not_reviewed')}
                    </dd>
                </div>
            </dl>

            {claim.review_note && (
                <div className="mt-4 rounded-lg bg-muted/60 p-3 text-sm">
                    <p className="text-xs font-medium text-muted-foreground">
                        {t('claims.review_note')}
                    </p>
                    <p className="mt-1 break-words whitespace-pre-line">
                        {claim.review_note}
                    </p>
                </div>
            )}

            {claim.status === 'pending' && (
                <p className="mt-4 text-sm text-muted-foreground">
                    {t('claims.pending_hint')}
                </p>
            )}

            <div className="mt-4 flex flex-wrap gap-2">
                {claim.status === 'approved' && (
                    <Button asChild size="sm">
                        <Link href="/manage">
                            <Building2 />
                            {t('claims.open_manage')}
                        </Link>
                    </Button>
                )}
                {claim.status === 'rejected' && mosque && (
                    <Button asChild size="sm" variant="outline">
                        <Link href={`/mosques/${mosque.slug}/claim`}>
                            <RotateCcw />
                            {t('claims.send_again')}
                        </Link>
                    </Button>
                )}
                {claim.document_url && (
                    <Button asChild size="sm" variant="ghost">
                        <a href={claim.document_url}>
                            <Download />
                            {t('claims.download_my_document')}
                        </a>
                    </Button>
                )}
            </div>
        </article>
    );
}
