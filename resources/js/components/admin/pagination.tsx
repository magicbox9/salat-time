import { Link } from '@inertiajs/react';
import { ChevronLeft, ChevronRight } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { useT } from '@/lib/i18n';
import { useFormatNumber } from './use-format-number';
import type { Paginated } from './types';

/** "Showing 1–25 of 3,585" with previous / next page links. */
export function Pagination({ page }: { page: Paginated<unknown> }) {
    const t = useT();
    const formatNumber = useFormatNumber();

    if (page.total === 0) {
        return null;
    }

    // Isolate the numeric range so it never flips inside right-to-left text.
    const range = `\u2066${formatNumber(page.from ?? 0)}–${formatNumber(page.to ?? 0)}\u2069`;

    return (
        <nav
            aria-label={t('admin.pagination')}
            className="flex flex-col items-center justify-between gap-3 sm:flex-row"
        >
            <p className="text-sm text-muted-foreground">
                {t('admin.showing', { range, total: formatNumber(page.total) })}
            </p>
            {page.last_page > 1 && (
                <div className="flex items-center gap-2">
                    <PageLink
                        href={page.prev_page_url}
                        label={t('admin.previous')}
                    >
                        <ChevronLeft className="rtl:rotate-180" />
                    </PageLink>
                    <span
                        className="min-w-16 text-center text-sm tabular-nums"
                        dir="ltr"
                    >
                        {page.current_page} / {page.last_page}
                    </span>
                    <PageLink href={page.next_page_url} label={t('admin.next')}>
                        <ChevronRight className="rtl:rotate-180" />
                    </PageLink>
                </div>
            )}
        </nav>
    );
}

function PageLink({
    href,
    label,
    children,
}: {
    href: string | null;
    label: string;
    children: React.ReactNode;
}) {
    if (!href) {
        return (
            <Button variant="outline" size="icon" disabled aria-label={label}>
                {children}
            </Button>
        );
    }

    return (
        <Button variant="outline" size="icon" asChild>
            <Link href={href} preserveState aria-label={label}>
                {children}
            </Link>
        </Button>
    );
}
