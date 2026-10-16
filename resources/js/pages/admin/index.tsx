import { Head, Link } from '@inertiajs/react';
import {
    BadgeCheck,
    Building2,
    CalendarClock,
    Inbox,
    MessageSquare,
    Newspaper,
    ShieldCheck,
    UserCog,
    Users,
} from 'lucide-react';
import { AdminShell } from '@/components/admin/admin-shell';
import { ClaimRowCompact } from '@/components/admin/claim-rows';
import { EmptyState } from '@/components/admin/empty-state';
import { StatCard } from '@/components/admin/stat-card';
import type { AdminPageProps, AdminStats } from '@/components/admin/types';
import type { AdminClaimRow } from '@/components/claims/types';
import { Button } from '@/components/ui/button';
import { useT } from '@/lib/i18n';

type Props = AdminPageProps & {
    stats: AdminStats;
    pendingClaims: AdminClaimRow[];
};

function share(part: number, total: number): string {
    return total > 0 ? `${Math.round((part / total) * 100)}%` : '0%';
}

/** /admin — platform figures and the requests waiting for a decision. */
export default function AdminOverview({
    stats,
    pendingClaims,
    pendingClaimsCount,
}: Props) {
    const t = useT();

    return (
        <>
            <Head title={t('admin.overview_title')} />
            <AdminShell
                title={t('admin.overview_title')}
                description={t('admin.overview_intro')}
                pendingClaimsCount={pendingClaimsCount}
            >
                <div className="grid grid-cols-2 gap-3 sm:gap-4 lg:grid-cols-4">
                    <StatCard
                        label={t('admin.stat_claims_pending')}
                        value={stats.claims_pending}
                        icon={Inbox}
                        href="/admin/claims"
                        highlight={stats.claims_pending > 0}
                    />
                    <StatCard
                        label={t('admin.stat_mosques')}
                        value={stats.mosques}
                        icon={Building2}
                        href="/admin/mosques"
                    />
                    <StatCard
                        label={t('admin.stat_with_times')}
                        value={stats.mosques_with_times}
                        icon={CalendarClock}
                        hint={t('admin.stat_share', {
                            share: share(
                                stats.mosques_with_times,
                                stats.mosques,
                            ),
                        })}
                        href="/admin/mosques?times=yes"
                    />
                    <StatCard
                        label={t('admin.stat_verified')}
                        value={stats.mosques_verified}
                        icon={BadgeCheck}
                        href="/admin/mosques?verified=yes"
                    />
                    <StatCard
                        label={t('admin.stat_users')}
                        value={stats.users}
                        icon={Users}
                        href="/admin/users"
                    />
                    <StatCard
                        label={t('admin.stat_managers')}
                        value={stats.managers}
                        icon={UserCog}
                        href="/admin/users?role=manager"
                    />
                    <StatCard
                        label={t('admin.stat_admins')}
                        value={stats.admins}
                        icon={ShieldCheck}
                        href="/admin/users?role=admin"
                    />
                    <StatCard
                        label={t('admin.stat_content')}
                        value={stats.posts}
                        icon={Newspaper}
                        hint={t('admin.stat_comments', {
                            count: stats.comments,
                        })}
                    />
                </div>

                <section className="rounded-xl border bg-card shadow-sm">
                    <div className="flex flex-wrap items-center justify-between gap-3 border-b px-5 py-4">
                        <div>
                            <h2 className="font-semibold">
                                {t('admin.pending_title')}
                            </h2>
                            <p className="text-sm text-muted-foreground">
                                {t('admin.pending_intro')}
                            </p>
                        </div>
                        <Button asChild variant="outline" size="sm">
                            <Link href="/admin/claims">
                                {t('admin.see_all_claims')}
                            </Link>
                        </Button>
                    </div>
                    {pendingClaims.length === 0 ? (
                        <EmptyState
                            icon={MessageSquare}
                            title={t('admin.pending_empty')}
                            className="m-5 border-none py-8"
                        />
                    ) : (
                        <ul className="divide-y">
                            {pendingClaims.map((claim) => (
                                <ClaimRowCompact key={claim.id} claim={claim} />
                            ))}
                        </ul>
                    )}
                </section>
            </AdminShell>
        </>
    );
}
