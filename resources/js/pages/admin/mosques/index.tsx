import { Head, Link } from '@inertiajs/react';
import { Building2, ChevronRight, Users } from 'lucide-react';
import { AdminShell } from '@/components/admin/admin-shell';
import { EmptyState } from '@/components/admin/empty-state';
import {
    FilterSelect,
    SearchField,
    useApplyFilters,
} from '@/components/admin/filters';
import { MosqueStatusBadges } from '@/components/admin/mosque-card';
import { Pagination } from '@/components/admin/pagination';
import type {
    AdminMosqueRow,
    AdminPageProps,
    Paginated,
} from '@/components/admin/types';
import { Button } from '@/components/ui/button';
import { useT } from '@/lib/i18n';

type Filters = {
    q: string | null;
    times: 'yes' | 'no' | null;
    verified: 'yes' | 'no' | null;
    source: string | null;
};

type Props = AdminPageProps & {
    mosques: Paginated<AdminMosqueRow>;
    filters: Filters;
    sources: string[];
};

/** /admin/mosques — search, filter and open mosque records. */
export default function AdminMosques({
    mosques,
    filters,
    sources,
    pendingClaimsCount,
}: Props) {
    const t = useT();
    const apply = useApplyFilters('/admin/mosques', filters);
    const yesNo = [
        { value: 'yes', label: t('admin.yes') },
        { value: 'no', label: t('admin.no') },
    ];

    return (
        <>
            <Head title={t('admin.mosques_title')} />
            <AdminShell
                title={t('admin.mosques_title')}
                description={t('admin.mosques_intro')}
                pendingClaimsCount={pendingClaimsCount}
            >
                <div className="flex flex-col gap-3 lg:flex-row lg:items-center lg:justify-between">
                    <SearchField
                        value={filters.q}
                        placeholder={t('admin.mosques_search')}
                        onSearch={(q) => apply({ q })}
                    />
                    <div className="grid grid-cols-1 gap-2 sm:flex sm:flex-wrap">
                        <FilterSelect
                            label={t('admin.filter_times')}
                            value={filters.times}
                            options={yesNo}
                            onChange={(times) => apply({ times })}
                        />
                        <FilterSelect
                            label={t('admin.filter_verified')}
                            value={filters.verified}
                            options={yesNo}
                            onChange={(verified) => apply({ verified })}
                        />
                        <FilterSelect
                            label={t('admin.filter_source')}
                            value={filters.source}
                            options={sources.map((source) => ({
                                value: source,
                                label: t(`admin.source_${source}`),
                            }))}
                            onChange={(source) => apply({ source })}
                        />
                    </div>
                </div>

                {mosques.data.length === 0 ? (
                    <EmptyState
                        icon={Building2}
                        title={t('admin.no_results')}
                        text={t('admin.no_results_hint')}
                    />
                ) : (
                    <>
                        <div className="hidden overflow-hidden rounded-xl border bg-card shadow-sm md:block">
                            <table className="w-full text-sm">
                                <thead className="bg-muted/50 text-xs text-muted-foreground">
                                    <tr>
                                        <th className="px-4 py-3 text-start font-medium">
                                            {t('admin.col_mosque')}
                                        </th>
                                        <th className="px-4 py-3 text-start font-medium">
                                            {t('admin.col_status')}
                                        </th>
                                        <th className="px-4 py-3 text-start font-medium">
                                            {t('admin.col_managers')}
                                        </th>
                                        <th className="px-4 py-3">
                                            <span className="sr-only">
                                                {t('admin.col_actions')}
                                            </span>
                                        </th>
                                    </tr>
                                </thead>
                                <tbody className="divide-y">
                                    {mosques.data.map((mosque) => (
                                        <tr
                                            key={mosque.id}
                                            className="transition-colors hover:bg-muted/30"
                                        >
                                            <td className="px-4 py-3">
                                                <p className="font-medium">
                                                    {mosque.name}
                                                </p>
                                                <p className="text-xs text-muted-foreground">
                                                    {[
                                                        mosque.postcode,
                                                        mosque.city,
                                                    ]
                                                        .filter(Boolean)
                                                        .join(' ') || '—'}
                                                </p>
                                            </td>
                                            <td className="px-4 py-3">
                                                <MosqueStatusBadges
                                                    mosque={mosque}
                                                />
                                            </td>
                                            <td className="px-4 py-3 tabular-nums">
                                                {mosque.managers_count}
                                            </td>
                                            <td className="px-4 py-3 text-end">
                                                <Button
                                                    asChild
                                                    size="sm"
                                                    variant="outline"
                                                >
                                                    <Link
                                                        href={`/admin/mosques/${mosque.slug}`}
                                                    >
                                                        {t('admin.open')}
                                                    </Link>
                                                </Button>
                                            </td>
                                        </tr>
                                    ))}
                                </tbody>
                            </table>
                        </div>

                        <ul className="grid gap-3 md:hidden">
                            {mosques.data.map((mosque) => (
                                <li key={mosque.id}>
                                    <Link
                                        href={`/admin/mosques/${mosque.slug}`}
                                        className="flex items-center gap-3 rounded-xl border bg-card p-4 shadow-sm transition-colors hover:border-primary/40"
                                    >
                                        <div className="min-w-0 flex-1 space-y-2">
                                            <div>
                                                <p className="truncate font-medium">
                                                    {mosque.name}
                                                </p>
                                                <p className="text-xs text-muted-foreground">
                                                    {[
                                                        mosque.postcode,
                                                        mosque.city,
                                                    ]
                                                        .filter(Boolean)
                                                        .join(' ') || '—'}
                                                </p>
                                            </div>
                                            <MosqueStatusBadges
                                                mosque={mosque}
                                            />
                                            {mosque.managers_count > 0 && (
                                                <p className="flex items-center gap-1.5 text-xs text-muted-foreground">
                                                    <Users
                                                        className="size-3.5"
                                                        aria-hidden
                                                    />
                                                    {t('admin.managers_count', {
                                                        count: mosque.managers_count,
                                                    })}
                                                </p>
                                            )}
                                        </div>
                                        <ChevronRight
                                            className="size-4 shrink-0 text-muted-foreground rtl:rotate-180"
                                            aria-hidden
                                        />
                                    </Link>
                                </li>
                            ))}
                        </ul>
                    </>
                )}

                <Pagination page={mosques} />
            </AdminShell>
        </>
    );
}
