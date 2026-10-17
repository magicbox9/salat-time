import { Link, router } from '@inertiajs/react';
import { Search, X } from 'lucide-react';
import { useState } from 'react';
import { Input } from '@/components/ui/input';
import { useT } from '@/lib/i18n';
import { cn } from '@/lib/utils';

export type BlogCategory = {
    id: number;
    name: string;
    slug: string;
    description: string | null;
    posts_count: number;
};

type Props = {
    slug: string;
    categories: BlogCategory[];
    filters: { category: string | null; q: string };
};

function blogUrl(slug: string, category: string | null, q: string): string {
    const params = new URLSearchParams();

    if (category) {
        params.set('category', category);
    }

    if (q) {
        params.set('q', q);
    }

    const query = params.toString();

    return `/mosques/${slug}/blog${query ? `?${query}` : ''}`;
}

/** Category chips and the search box of the blog. */
export function BlogFilters({ slug, categories, filters }: Props) {
    const t = useT();
    const [q, setQ] = useState(filters.q);
    const chip = (active: boolean) =>
        cn(
            'flex shrink-0 items-center gap-1.5 rounded-full border px-3 py-1.5 text-sm font-medium transition-colors outline-none focus-visible:ring-2 focus-visible:ring-[var(--site-accent)]/50',
            active
                ? 'border-transparent bg-[var(--site-accent)] text-[var(--site-accent-fg)]'
                : 'bg-card text-muted-foreground hover:text-foreground',
        );
    const visible = categories.filter(
        (c) => c.posts_count > 0 || c.slug === filters.category,
    );

    return (
        <div className="flex flex-col gap-3 lg:flex-row lg:items-center lg:justify-between">
            <nav
                aria-label={t('mosquesite.categories')}
                className="-mx-1 flex [scrollbar-width:none] gap-1.5 overflow-x-auto px-1 pb-1"
            >
                <Link
                    href={blogUrl(slug, null, filters.q)}
                    className={chip(filters.category === null)}
                    aria-current={
                        filters.category === null ? 'page' : undefined
                    }
                    preserveScroll
                >
                    {t('mosquesite.all_posts')}
                </Link>
                {visible.map((category) => (
                    <Link
                        key={category.id}
                        href={blogUrl(slug, category.slug, filters.q)}
                        className={chip(filters.category === category.slug)}
                        aria-current={
                            filters.category === category.slug
                                ? 'page'
                                : undefined
                        }
                        preserveScroll
                    >
                        {category.name}
                        <span className="text-xs tabular-nums opacity-70">
                            {category.posts_count}
                        </span>
                    </Link>
                ))}
            </nav>

            <form
                role="search"
                className="relative lg:w-72"
                onSubmit={(event) => {
                    event.preventDefault();
                    router.get(
                        blogUrl(slug, filters.category, q.trim()),
                        {},
                        { preserveScroll: true },
                    );
                }}
            >
                <label htmlFor="blog-search" className="sr-only">
                    {t('mosquesite.search_label')}
                </label>
                <Search
                    className="pointer-events-none absolute start-3 top-1/2 size-4 -translate-y-1/2 text-muted-foreground"
                    aria-hidden
                />
                <Input
                    id="blog-search"
                    type="search"
                    value={q}
                    maxLength={100}
                    onChange={(event) => setQ(event.target.value)}
                    placeholder={t('mosquesite.search_placeholder')}
                    className="rounded-full ps-9 pe-9"
                />
                {filters.q && (
                    <Link
                        href={blogUrl(slug, filters.category, '')}
                        className="absolute end-2 top-1/2 flex size-7 -translate-y-1/2 items-center justify-center rounded-full text-muted-foreground hover:bg-accent hover:text-foreground"
                        aria-label={t('mosquesite.clear_search')}
                        preserveScroll
                    >
                        <X className="size-4" />
                    </Link>
                )}
            </form>
        </div>
    );
}
