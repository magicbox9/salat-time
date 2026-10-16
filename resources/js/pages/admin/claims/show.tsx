import { Head, Link } from '@inertiajs/react';
import { BadgeCheck, Download, FileX, Mail, ShieldCheck } from 'lucide-react';
import { AdminShell, BackLink } from '@/components/admin/admin-shell';
import { ClaimDecision } from '@/components/admin/claim-decision';
import { ManagersList } from '@/components/admin/managers-list';
import type { AdminMosqueDetails } from '@/components/admin/mosque-card';
import { MosqueCard } from '@/components/admin/mosque-card';
import { InfoList, InfoRow, Panel } from '@/components/admin/panel';
import type { AdminManager, AdminPageProps } from '@/components/admin/types';
import { ClaimStatusBadge } from '@/components/claims/claim-status-badge';
import type { AdminClaim, AdminClaimRow } from '@/components/claims/types';
import { useFormatDate } from '@/components/claims/use-format-date';
import { Badge } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';
import { useT } from '@/lib/i18n';

type Claimant = {
    id: number;
    name: string;
    email: string;
    verified: boolean;
    joined_at: string | null;
    is_admin: boolean;
    managed_count: number;
    claims_count: number;
};

type Props = AdminPageProps & {
    claim: AdminClaim;
    claimant: Claimant;
    mosque: AdminMosqueDetails;
    managers: AdminManager[];
    otherClaims: AdminClaimRow[];
};

/** /admin/claims/{id} — everything needed to decide on one request. */
export default function AdminClaimShow({
    claim,
    claimant,
    mosque,
    managers,
    otherClaims,
    pendingClaimsCount,
}: Props) {
    const t = useT();
    const formatDate = useFormatDate();

    return (
        <>
            <Head title={t('admin.claim_title', { id: claim.id })} />
            <AdminShell
                title={mosque.name}
                description={t('admin.claim_submitted', {
                    date: formatDate(claim.created_at, 'datetime'),
                })}
                back={
                    <BackLink
                        href="/admin/claims"
                        label={t('admin.back_to_claims')}
                    />
                }
                actions={
                    <ClaimStatusBadge
                        status={claim.status}
                        className="text-sm"
                    />
                }
                pendingClaimsCount={pendingClaimsCount}
            >
                <div className="grid items-start gap-6 lg:grid-cols-3">
                    <div className="space-y-6 lg:col-span-2">
                        <Panel title={t('admin.request')}>
                            <InfoList className="sm:grid-cols-2">
                                <InfoRow label={t('claims.field_role')}>
                                    <span className="font-medium">
                                        {claim.role_at_mosque}
                                    </span>
                                </InfoRow>
                                <InfoRow label={t('claims.field_phone')}>
                                    {claim.phone ? (
                                        <a
                                            href={`tel:${claim.phone}`}
                                            className="underline-offset-4 hover:underline"
                                            dir="ltr"
                                        >
                                            {claim.phone}
                                        </a>
                                    ) : (
                                        <span className="text-muted-foreground">
                                            —
                                        </span>
                                    )}
                                </InfoRow>
                            </InfoList>
                            <div className="mt-5">
                                <p className="text-xs text-muted-foreground">
                                    {t('claims.field_message')}
                                </p>
                                {claim.message ? (
                                    <p className="mt-1 rounded-lg bg-muted/50 p-3 text-sm break-words whitespace-pre-line">
                                        {claim.message}
                                    </p>
                                ) : (
                                    <p className="mt-1 text-sm text-muted-foreground">
                                        {t('admin.no_message')}
                                    </p>
                                )}
                            </div>
                            <div className="mt-5">
                                {claim.document_url ? (
                                    <Button asChild variant="outline">
                                        <a href={claim.document_url}>
                                            <Download />
                                            {t('admin.download_document')}
                                        </a>
                                    </Button>
                                ) : (
                                    <p className="flex items-center gap-2 text-sm text-muted-foreground">
                                        <FileX className="size-4" aria-hidden />
                                        {t('admin.no_document')}
                                    </p>
                                )}
                            </div>
                        </Panel>

                        <ClaimDecision claim={claim} />

                        <Panel title={t('admin.current_managers')}>
                            <ManagersList managers={managers} />
                        </Panel>

                        {otherClaims.length > 0 && (
                            <Panel title={t('admin.other_claims')}>
                                <ul className="divide-y">
                                    {otherClaims.map((other) => (
                                        <li
                                            key={other.id}
                                            className="flex flex-wrap items-center gap-3 py-3 first:pt-0 last:pb-0"
                                        >
                                            <div className="min-w-0 flex-1">
                                                <Link
                                                    href={`/admin/claims/${other.id}`}
                                                    className="font-medium underline-offset-4 hover:underline"
                                                >
                                                    {other.user?.name ?? '—'}
                                                </Link>
                                                <p className="text-xs text-muted-foreground">
                                                    {formatDate(
                                                        other.created_at,
                                                    )}
                                                </p>
                                            </div>
                                            <ClaimStatusBadge
                                                status={other.status}
                                            />
                                        </li>
                                    ))}
                                </ul>
                            </Panel>
                        )}
                    </div>

                    <div className="space-y-6">
                        <Panel title={t('admin.claimant')}>
                            <div className="space-y-4">
                                <div>
                                    <div className="flex flex-wrap items-center gap-2">
                                        <p className="font-medium">
                                            {claimant.name}
                                        </p>
                                        {claimant.is_admin && (
                                            <Badge
                                                variant="secondary"
                                                className="rounded-full"
                                            >
                                                <ShieldCheck aria-hidden />
                                                {t('admin.admin_badge')}
                                            </Badge>
                                        )}
                                    </div>
                                    <a
                                        href={`mailto:${claimant.email}`}
                                        className="mt-1 inline-flex items-center gap-1.5 text-sm text-muted-foreground underline-offset-4 hover:underline"
                                    >
                                        <Mail
                                            className="size-3.5"
                                            aria-hidden
                                        />
                                        <span dir="ltr">{claimant.email}</span>
                                    </a>
                                </div>
                                <InfoList className="grid-cols-2">
                                    <InfoRow label={t('admin.email_status')}>
                                        {claimant.verified ? (
                                            <span className="inline-flex items-center gap-1 text-primary">
                                                <BadgeCheck
                                                    className="size-3.5"
                                                    aria-hidden
                                                />
                                                {t('admin.email_verified')}
                                            </span>
                                        ) : (
                                            t('admin.email_unverified')
                                        )}
                                    </InfoRow>
                                    <InfoRow label={t('admin.joined')}>
                                        {formatDate(claimant.joined_at)}
                                    </InfoRow>
                                    <InfoRow label={t('admin.col_managed')}>
                                        {claimant.managed_count}
                                    </InfoRow>
                                    <InfoRow label={t('admin.claims_sent')}>
                                        {claimant.claims_count}
                                    </InfoRow>
                                </InfoList>
                            </div>
                        </Panel>

                        <MosqueCard mosque={mosque} />
                    </div>
                </div>
            </AdminShell>
        </>
    );
}
