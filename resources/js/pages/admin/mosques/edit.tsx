import { Head, Link } from '@inertiajs/react';
import { ExternalLink } from 'lucide-react';
import { AdminShell, BackLink } from '@/components/admin/admin-shell';
import { ManagersList } from '@/components/admin/managers-list';
import { MosqueStatusBadges } from '@/components/admin/mosque-card';
import { MosqueForm } from '@/components/admin/mosque-form';
import { Panel } from '@/components/admin/panel';
import type { AdminManager, AdminPageProps } from '@/components/admin/types';
import { VerificationPanel } from '@/components/admin/verification-panel';
import type { AdminClaimRow } from '@/components/claims/types';
import { useFormatDate } from '@/components/claims/use-format-date';
import { Button } from '@/components/ui/button';
import { useT } from '@/lib/i18n';
import type { MosqueSummary } from '@/types/mosque';

type Props = AdminPageProps & {
    mosque: MosqueSummary & { verified_at: string | null };
    managers: AdminManager[];
    pendingClaims: AdminClaimRow[];
    timezones: string[];
};

/** /admin/mosques/{slug} — correct the record, verify it, manage who runs it. */
export default function AdminMosqueEdit({
    mosque,
    managers,
    pendingClaims,
    timezones,
    pendingClaimsCount,
}: Props) {
    const t = useT();
    const formatDate = useFormatDate();

    return (
        <>
            <Head title={mosque.name} />
            <AdminShell
                title={mosque.name}
                back={
                    <BackLink
                        href="/admin/mosques"
                        label={t('admin.back_to_mosques')}
                    />
                }
                actions={
                    <Button asChild variant="outline" size="sm">
                        <a
                            href={`/mosques/${mosque.slug}`}
                            target="_blank"
                            rel="noreferrer"
                        >
                            <ExternalLink />
                            {t('admin.public_page')}
                        </a>
                    </Button>
                }
                pendingClaimsCount={pendingClaimsCount}
            >
                <MosqueStatusBadges mosque={mosque} />

                <div className="grid items-start gap-6 lg:grid-cols-3">
                    <Panel
                        title={t('admin.details')}
                        description={t('admin.details_intro')}
                        className="lg:col-span-2"
                    >
                        <MosqueForm
                            key={mosque.slug}
                            mosque={mosque}
                            timezones={timezones}
                        />
                    </Panel>

                    <div className="space-y-6">
                        <VerificationPanel
                            slug={mosque.slug}
                            name={mosque.name}
                            verifiedAt={mosque.verified_at}
                        />

                        <Panel title={t('admin.current_managers')}>
                            <ManagersList
                                managers={managers}
                                revoke={{
                                    mosqueSlug: mosque.slug,
                                    mosqueName: mosque.name,
                                }}
                            />
                        </Panel>

                        {pendingClaims.length > 0 && (
                            <Panel title={t('admin.pending_for_mosque')}>
                                <ul className="divide-y">
                                    {pendingClaims.map((claim) => (
                                        <li
                                            key={claim.id}
                                            className="py-3 first:pt-0 last:pb-0"
                                        >
                                            <Link
                                                href={`/admin/claims/${claim.id}`}
                                                className="font-medium underline-offset-4 hover:underline"
                                            >
                                                {claim.user?.name ?? '—'}
                                            </Link>
                                            <p className="text-xs text-muted-foreground">
                                                {claim.role_at_mosque} ·{' '}
                                                {formatDate(claim.created_at)}
                                            </p>
                                        </li>
                                    ))}
                                </ul>
                            </Panel>
                        )}
                    </div>
                </div>
            </AdminShell>
        </>
    );
}
