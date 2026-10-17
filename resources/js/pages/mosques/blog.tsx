import { Link } from '@inertiajs/react';
import { Mic, Newspaper, Plus, SearchX } from 'lucide-react';
import { BlogCard } from '@/components/mosque/blog-card';
import { BlogFilters } from '@/components/mosque/blog-filters';
import type { BlogCategory } from '@/components/mosque/blog-filters';
import { SiteHead } from '@/components/mosque/site-head';
import { SitePager } from '@/components/mosque/site-pager';
import type { PageOf } from '@/components/mosque/site-pager';
import { MosqueSiteShell } from '@/components/mosque/site-shell';
import type {
    PostCardData,
    SiteMeta,
    SiteShell,
} from '@/components/mosque/site-types';
import { Button } from '@/components/ui/button';
import { useT } from '@/lib/i18n';

type Props = {
    site: SiteShell;
    categories: BlogCategory[];
    filters: { category: string | null; q: string };
    activeCategory: { name: string; description: string | null } | null;
    posts: PageOf<PostCardData>;
    canManage: boolean;
    meta: SiteMeta;
};

/** A mosque's blog: khutbahs, news, events, lessons, announcements. */
export default function MosqueBlog({
    site,
    categories,
    filters,
    activeCategory,
    posts,
    canManage,
    meta,
}: Props) {
    const t = useT();
    const khutbahs = filters.category === 'khutbah';
    const filtered = filters.category !== null || filters.q !== '';

    return (
        <>
            <SiteHead meta={meta} />
            <MosqueSiteShell
                site={site}
                current={khutbahs ? 'khutbah' : 'blog'}
            >
                <div className="space-y-6">
                    <header className="flex flex-wrap items-end justify-between gap-4">
                        <div className="min-w-0">
                            <h1 className="flex items-center gap-2 text-2xl font-semibold tracking-tight sm:text-3xl">
                                {khutbahs && (
                                    <Mic
                                        className="size-6 text-[var(--site-accent-ink)]"
                                        aria-hidden
                                    />
                                )}
                                {activeCategory?.name ??
                                    t('mosquesite.blog_title')}
                            </h1>
                            <p className="mt-1 max-w-2xl text-muted-foreground">
                                {activeCategory?.description ||
                                    (khutbahs
                                        ? t('mosquesite.khutbahs_intro')
                                        : t('mosquesite.blog_intro', {
                                              name: site.name,
                                          }))}
                            </p>
                        </div>
                        {canManage && (
                            <Button asChild variant="outline" size="sm">
                                <Link
                                    href={`/manage/${site.slug}/posts/create`}
                                >
                                    <Plus className="size-4" />
                                    {t('mosque.new_post')}
                                </Link>
                            </Button>
                        )}
                    </header>

                    <BlogFilters
                        slug={site.slug}
                        categories={categories}
                        filters={filters}
                    />

                    {filters.q && (
                        <p
                            className="text-sm text-muted-foreground"
                            aria-live="polite"
                        >
                            {t('mosquesite.search_results', {
                                count: posts.total,
                                q: filters.q,
                            })}
                        </p>
                    )}

                    {posts.data.length === 0 ? (
                        <div className="rounded-2xl border border-dashed px-6 py-14 text-center">
                            {filtered ? (
                                <SearchX
                                    className="mx-auto size-8 text-muted-foreground/60"
                                    aria-hidden
                                />
                            ) : (
                                <Newspaper
                                    className="mx-auto size-8 text-muted-foreground/60"
                                    aria-hidden
                                />
                            )}
                            <p className="mt-3 font-medium">
                                {filtered
                                    ? t('mosquesite.no_results')
                                    : t('mosque.no_posts')}
                            </p>
                            <p className="mt-1 text-sm text-muted-foreground">
                                {filtered
                                    ? t('mosquesite.no_results_hint')
                                    : canManage
                                      ? t('mosque.no_posts_manager')
                                      : t('mosque.no_posts_hint')}
                            </p>
                            {filtered && (
                                <Button
                                    asChild
                                    variant="outline"
                                    size="sm"
                                    className="mt-4"
                                >
                                    <Link href={`/mosques/${site.slug}/blog`}>
                                        {t('mosquesite.all_posts')}
                                    </Link>
                                </Button>
                            )}
                        </div>
                    ) : (
                        <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
                            {posts.data.map((post) => (
                                <BlogCard
                                    key={post.id}
                                    post={post}
                                    timezone={site.timezone}
                                />
                            ))}
                        </div>
                    )}

                    <SitePager page={posts} />
                </div>
            </MosqueSiteShell>
        </>
    );
}
