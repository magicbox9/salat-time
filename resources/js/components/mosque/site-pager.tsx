import { Link } from '@inertiajs/react';
import { ChevronLeft, ChevronRight } from 'lucide-react';
import { useT } from '@/lib/i18n';
import { cn } from '@/lib/utils';

/** Laravel's LengthAwarePaginator, as Inertia receives it. */
export type PageOf<T> = {
    data: T[];
    current_page: number;
    last_page: number;
    total: number;
    prev_page_url: string | null;
    next_page_url: string | null;
    links: { url: string | null; label: string; active: boolean }[];
};

/** Previous / page numbers / next, under a list of the mosque's site. */
export function SitePager({ page }: { page: PageOf<unknown> }) {
    const t = useT();

    if (page.last_page <= 1) {
        return null;
    }

    // The middle links are the page numbers (and "…" gaps).
    const numbers = page.links.slice(1, -1);
    const step = (href: string | null, label: string, next: boolean) => {
        const Icon = next ? ChevronRight : ChevronLeft;
        const content = (
            <>
                {!next && (
                    <Icon className="size-4 rtl:rotate-180" aria-hidden />
                )}
                <span className="hidden sm:inline">{label}</span>
                {next && <Icon className="size-4 rtl:rotate-180" aria-hidden />}
            </>
        );
        const className =
            'flex h-9 items-center gap-1 rounded-xl border px-3 text-sm font-medium transition-colors';

        return href ? (
            <Link
                href={href}
                preserveScroll={false}
                className={cn(className, 'hover:bg-accent')}
                aria-label={label}
            >
                {content}
            </Link>
        ) : (
            <span aria-disabled="true" className={cn(className, 'opacity-40')}>
                {content}
            </span>
        );
    };

    return (
        <nav
            className="flex items-center justify-center gap-2"
            aria-label={t('mosquesite.pagination')}
        >
            {step(page.prev_page_url, t('manage.previous'), false)}
            <ol className="flex items-center gap-1" dir="ltr">
                {numbers.map((link, index) => (
                    <li key={`${link.label}-${index}`}>
                        {link.url && !link.active ? (
                            <Link
                                href={link.url}
                                className="flex size-9 items-center justify-center rounded-xl text-sm tabular-nums transition-colors hover:bg-accent"
                            >
                                {link.label}
                            </Link>
                        ) : (
                            <span
                                aria-current={link.active ? 'page' : undefined}
                                className={cn(
                                    'flex size-9 items-center justify-center rounded-xl text-sm tabular-nums',
                                    link.active &&
                                        'bg-[var(--site-accent)] font-semibold text-[var(--site-accent-fg)]',
                                )}
                            >
                                {link.label}
                            </span>
                        )}
                    </li>
                ))}
            </ol>
            {step(page.next_page_url, t('manage.next'), true)}
        </nav>
    );
}
