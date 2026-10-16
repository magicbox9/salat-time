import { Head } from '@inertiajs/react';
import { BadgeCheck, ShieldCheck, Users } from 'lucide-react';
import { AdminShell } from '@/components/admin/admin-shell';
import { AdminToggle } from '@/components/admin/admin-toggle';
import { EmptyState } from '@/components/admin/empty-state';
import {
    FilterSelect,
    SearchField,
    useApplyFilters,
} from '@/components/admin/filters';
import { Pagination } from '@/components/admin/pagination';
import type {
    AdminPageProps,
    AdminUserRow,
    Paginated,
} from '@/components/admin/types';
import { useFormatDate } from '@/components/claims/use-format-date';
import { Badge } from '@/components/ui/badge';
import { useT } from '@/lib/i18n';

type Props = AdminPageProps & {
    users: Paginated<AdminUserRow>;
    filters: {
        q: string | null;
        role: 'admin' | 'manager' | 'unverified' | null;
    };
    adminCount: number;
};

function UserIdentity({ user }: { user: AdminUserRow }) {
    const t = useT();

    return (
        <div className="min-w-0">
            <div className="flex flex-wrap items-center gap-1.5">
                <span className="font-medium">{user.name}</span>
                {user.is_self && (
                    <Badge variant="outline" className="rounded-full">
                        {t('admin.you')}
                    </Badge>
                )}
                {user.is_admin && (
                    <Badge variant="secondary" className="rounded-full">
                        <ShieldCheck aria-hidden />
                        {t('admin.admin_badge')}
                    </Badge>
                )}
            </div>
            <p className="truncate text-xs text-muted-foreground">
                <span dir="ltr">{user.email}</span>
            </p>
        </div>
    );
}

function EmailStatus({ verified }: { verified: boolean }) {
    const t = useT();

    return verified ? (
        <span className="inline-flex items-center gap-1 text-primary">
            <BadgeCheck className="size-3.5" aria-hidden />
            {t('admin.email_verified')}
        </span>
    ) : (
        <span className="text-muted-foreground">
            {t('admin.email_unverified')}
        </span>
    );
}

/** /admin/users — accounts and admin rights. */
export default function AdminUsers({
    users,
    filters,
    adminCount,
    pendingClaimsCount,
}: Props) {
    const t = useT();
    const formatDate = useFormatDate();
    const apply = useApplyFilters('/admin/users', filters);

    return (
        <>
            <Head title={t('admin.users_title')} />
            <AdminShell
                title={t('admin.users_title')}
                description={t('admin.users_intro')}
                pendingClaimsCount={pendingClaimsCount}
            >
                <div className="flex flex-col gap-3 lg:flex-row lg:items-center lg:justify-between">
                    <SearchField
                        value={filters.q}
                        placeholder={t('admin.users_search')}
                        onSearch={(q) => apply({ q })}
                    />
                    <FilterSelect
                        label={t('admin.filter_role')}
                        value={filters.role}
                        options={[
                            { value: 'admin', label: t('admin.role_admins') },
                            {
                                value: 'manager',
                                label: t('admin.role_managers'),
                            },
                            {
                                value: 'unverified',
                                label: t('admin.role_unverified'),
                            },
                        ]}
                        onChange={(role) => apply({ role })}
                    />
                </div>

                {users.data.length === 0 ? (
                    <EmptyState icon={Users} title={t('admin.no_results')} />
                ) : (
                    <>
                        <div className="hidden overflow-hidden rounded-xl border bg-card shadow-sm md:block">
                            <table className="w-full text-sm">
                                <thead className="bg-muted/50 text-xs text-muted-foreground">
                                    <tr>
                                        <th className="px-4 py-3 text-start font-medium">
                                            {t('admin.col_user')}
                                        </th>
                                        <th className="px-4 py-3 text-start font-medium">
                                            {t('admin.joined')}
                                        </th>
                                        <th className="px-4 py-3 text-start font-medium">
                                            {t('admin.email_status')}
                                        </th>
                                        <th className="px-4 py-3 text-start font-medium">
                                            {t('admin.col_managed')}
                                        </th>
                                        <th className="px-4 py-3">
                                            <span className="sr-only">
                                                {t('admin.col_actions')}
                                            </span>
                                        </th>
                                    </tr>
                                </thead>
                                <tbody className="divide-y">
                                    {users.data.map((user) => (
                                        <tr
                                            key={user.id}
                                            className="transition-colors hover:bg-muted/30"
                                        >
                                            <td className="px-4 py-3">
                                                <UserIdentity user={user} />
                                            </td>
                                            <td className="px-4 py-3 whitespace-nowrap text-muted-foreground">
                                                {formatDate(user.joined_at)}
                                            </td>
                                            <td className="px-4 py-3">
                                                <EmailStatus
                                                    verified={user.verified}
                                                />
                                            </td>
                                            <td className="px-4 py-3 tabular-nums">
                                                {user.managed_count}
                                            </td>
                                            <td className="px-4 py-3 text-end">
                                                <AdminToggle
                                                    user={user}
                                                    adminCount={adminCount}
                                                />
                                            </td>
                                        </tr>
                                    ))}
                                </tbody>
                            </table>
                        </div>

                        <ul className="grid gap-3 md:hidden">
                            {users.data.map((user) => (
                                <li
                                    key={user.id}
                                    className="space-y-3 rounded-xl border bg-card p-4 shadow-sm"
                                >
                                    <UserIdentity user={user} />
                                    <div className="flex flex-wrap gap-x-4 gap-y-1 text-xs text-muted-foreground">
                                        <span>
                                            {t('admin.joined_on', {
                                                date: formatDate(
                                                    user.joined_at,
                                                ),
                                            })}
                                        </span>
                                        <EmailStatus verified={user.verified} />
                                        <span>
                                            {t('admin.managers_count_user', {
                                                count: user.managed_count,
                                            })}
                                        </span>
                                    </div>
                                    <AdminToggle
                                        user={user}
                                        adminCount={adminCount}
                                    />
                                </li>
                            ))}
                        </ul>
                    </>
                )}

                <Pagination page={users} />
            </AdminShell>
        </>
    );
}
