import { Link } from '@inertiajs/react';
import { ChevronLeft, ChevronRight } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { useT } from '@/lib/i18n';

/** Laravel's paginator, as Inertia receives it. */
export type Paginated<T> = {
    data: T[];
    current_page: number;
    last_page?: number;
    total?: number;
    prev_page_url: string | null;
    next_page_url: string | null;
};

/** Previous / next links under a paginated list. */
export function Pager({ page }: { page: Paginated<unknown> }) {
    const t = useT();

    if (!page.prev_page_url && !page.next_page_url) {
        return null;
    }

    return (
        <nav
            className="flex items-center justify-between gap-3"
            aria-label={t('manage.pagination')}
        >
            <Button asChild variant="outline" size="sm">
                {page.prev_page_url ? (
                    <Link href={page.prev_page_url} preserveScroll>
                        <ChevronLeft className="size-4 rtl:rotate-180" />
                        {t('manage.previous')}
                    </Link>
                ) : (
                    <span
                        aria-disabled="true"
                        className="pointer-events-none opacity-50"
                    >
                        <ChevronLeft className="size-4 rtl:rotate-180" />
                        {t('manage.previous')}
                    </span>
                )}
            </Button>
            {page.last_page !== undefined && (
                <span
                    className="text-sm text-muted-foreground tabular-nums"
                    dir="ltr"
                >
                    {page.current_page} / {page.last_page}
                </span>
            )}
            <Button asChild variant="outline" size="sm">
                {page.next_page_url ? (
                    <Link href={page.next_page_url} preserveScroll>
                        {t('manage.next')}
                        <ChevronRight className="size-4 rtl:rotate-180" />
                    </Link>
                ) : (
                    <span
                        aria-disabled="true"
                        className="pointer-events-none opacity-50"
                    >
                        {t('manage.next')}
                        <ChevronRight className="size-4 rtl:rotate-180" />
                    </span>
                )}
            </Button>
        </nav>
    );
}
