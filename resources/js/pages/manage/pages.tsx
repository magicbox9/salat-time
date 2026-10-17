import { Link } from '@inertiajs/react';
import { ExternalLink, EyeOff, Menu, PencilLine, Plus } from 'lucide-react';
import { ConfirmDelete } from '@/components/manage/confirm-delete';
import { ManageLayout } from '@/components/manage/manage-layout';
import { StatusBadge } from '@/components/manage/status-badge';
import { Button } from '@/components/ui/button';
import { useT } from '@/lib/i18n';
import type { MosqueSummary } from '@/types/mosque';

type ManagedPage = {
    id: number;
    title: string;
    slug: string;
    sort: number;
    show_in_menu: boolean;
    published: boolean;
    url: string;
    updated_at: string | null;
};

type Props = { mosque: MosqueSummary; pages: ManagedPage[]; max: number };

/** The site's pages: About us, Courses, Contact… */
export default function ManagePages({ mosque, pages, max }: Props) {
    const t = useT();
    const base = `/manage/${mosque.slug}/pages`;

    return (
        <ManageLayout
            mosque={mosque}
            title={t('manage.pages_title')}
            description={t('manage.pages_intro')}
            actions={
                pages.length < max && (
                    <Button asChild>
                        <Link href={`${base}/create`}>
                            <Plus className="size-4" aria-hidden />
                            {t('manage.new_page')}
                        </Link>
                    </Button>
                )
            }
        >
            {pages.length === 0 ? (
                <div className="rounded-2xl border border-dashed px-6 py-12 text-center">
                    <p className="font-medium">{t('manage.no_pages')}</p>
                    <p className="mx-auto mt-1 max-w-md text-sm text-muted-foreground">
                        {t('manage.no_pages_hint')}
                    </p>
                    <Button asChild variant="outline" className="mt-5">
                        <Link href={`${base}/create`}>
                            <Plus className="size-4" aria-hidden />
                            {t('manage.new_page')}
                        </Link>
                    </Button>
                </div>
            ) : (
                <ul className="divide-y rounded-2xl border bg-card shadow-xs">
                    {pages.map((page) => (
                        <li
                            key={page.id}
                            className="flex flex-col gap-3 p-4 sm:flex-row sm:items-center"
                        >
                            <div className="min-w-0 flex-1">
                                <div className="flex flex-wrap items-center gap-2 text-xs text-muted-foreground">
                                    <StatusBadge
                                        status={
                                            page.published
                                                ? 'published'
                                                : 'draft'
                                        }
                                    />
                                    {page.show_in_menu ? (
                                        <span className="inline-flex items-center gap-1">
                                            <Menu
                                                className="size-3.5"
                                                aria-hidden
                                            />
                                            {t('manage.in_menu', {
                                                n: page.sort,
                                            })}
                                        </span>
                                    ) : (
                                        <span className="inline-flex items-center gap-1">
                                            <EyeOff
                                                className="size-3.5"
                                                aria-hidden
                                            />
                                            {t('manage.not_in_menu')}
                                        </span>
                                    )}
                                    <span className="font-mono" dir="ltr">
                                        /pages/{page.slug}
                                    </span>
                                </div>
                                <p
                                    dir="auto"
                                    className="mt-1 truncate font-medium"
                                >
                                    {page.title}
                                </p>
                            </div>
                            <div className="flex shrink-0 items-center gap-1">
                                <Button
                                    asChild
                                    variant="ghost"
                                    size="icon"
                                    aria-label={t('manage.view_page')}
                                >
                                    <Link href={page.url}>
                                        <ExternalLink className="size-4" />
                                    </Link>
                                </Button>
                                <Button asChild variant="outline" size="sm">
                                    <Link href={`${base}/${page.id}/edit`}>
                                        <PencilLine
                                            className="size-4"
                                            aria-hidden
                                        />
                                        {t('manage.edit')}
                                    </Link>
                                </Button>
                                <ConfirmDelete
                                    url={`${base}/${page.id}`}
                                    title={t('manage.delete_page_title')}
                                    description={t('manage.delete_page_body', {
                                        title: page.title,
                                    })}
                                    iconOnly
                                />
                            </div>
                        </li>
                    ))}
                </ul>
            )}
        </ManageLayout>
    );
}
