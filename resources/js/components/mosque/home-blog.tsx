import { Link } from '@inertiajs/react';
import { ArrowRight, Newspaper, Plus } from 'lucide-react';
import { useId, useState } from 'react';
import { Button } from '@/components/ui/button';
import { useT } from '@/lib/i18n';
import { cn } from '@/lib/utils';
import { BlogCard } from './blog-card';
import type { LatestGroup, SiteShell } from './site-types';

type Props = {
    site: SiteShell;
    groups: LatestGroup[];
    canManage: boolean;
};

/** The newest posts, one tab per category. */
export function HomeBlog({ site, groups, canManage }: Props) {
    const t = useT();
    const id = useId();
    const [active, setActive] = useState(0);
    const current = Math.max(0, Math.min(active, groups.length - 1));
    const group = groups[current];
    const blog = `/mosques/${site.slug}/blog`;
    const label = (g: LatestGroup) =>
        g.category?.name ?? t('mosquesite.other_posts');

    // Arrow keys move between the tabs (mirrored in right-to-left), Home/End jump to the ends.
    const onTabKey = (event: React.KeyboardEvent<HTMLDivElement>) => {
        const rtl = getComputedStyle(event.currentTarget).direction === 'rtl';
        const steps: Partial<Record<string, number>> = {
            ArrowRight: rtl ? -1 : 1,
            ArrowLeft: rtl ? 1 : -1,
        };
        const step = steps[event.key];
        const last = groups.length - 1;
        const next =
            event.key === 'Home'
                ? 0
                : event.key === 'End'
                  ? last
                  : step === undefined
                    ? null
                    : (current + step + groups.length) % groups.length;

        if (next === null) {
            return;
        }

        event.preventDefault();
        setActive(next);
        document.getElementById(`${id}-tab-${next}`)?.focus();
    };

    return (
        <section
            aria-labelledby="mosque-news"
            id="news"
            className="scroll-mt-36 space-y-4"
        >
            <div className="flex flex-wrap items-end justify-between gap-3">
                <div>
                    <h2
                        id="mosque-news"
                        className="text-xl font-semibold tracking-tight"
                    >
                        {t('mosquesite.latest_title')}
                    </h2>
                    <p className="text-sm text-muted-foreground">
                        {t('mosquesite.latest_intro')}
                    </p>
                </div>
                <div className="flex items-center gap-2">
                    {canManage && (
                        <Button asChild size="sm" variant="outline">
                            <Link href={`/manage/${site.slug}/posts/create`}>
                                <Plus className="size-4" />
                                {t('mosque.new_post')}
                            </Link>
                        </Button>
                    )}
                    <Button asChild size="sm" variant="ghost">
                        <Link
                            href={
                                group?.category
                                    ? `${blog}?category=${group.category.slug}`
                                    : blog
                            }
                        >
                            {t('mosquesite.see_all')}
                            <ArrowRight
                                className="size-4 rtl:-scale-x-100"
                                aria-hidden
                            />
                        </Link>
                    </Button>
                </div>
            </div>

            {!group ? (
                <div className="rounded-2xl border border-dashed px-6 py-10 text-center">
                    <Newspaper
                        className="mx-auto size-8 text-muted-foreground/60"
                        aria-hidden
                    />
                    <p className="mt-3 font-medium">{t('mosque.no_posts')}</p>
                    <p className="mt-1 text-sm text-muted-foreground">
                        {canManage
                            ? t('mosque.no_posts_manager')
                            : t('mosque.no_posts_hint')}
                    </p>
                </div>
            ) : (
                <>
                    {groups.length > 1 && (
                        <div
                            role="tablist"
                            aria-label={t('mosquesite.categories')}
                            onKeyDown={onTabKey}
                            className="flex [scrollbar-width:none] gap-1.5 overflow-x-auto pb-1"
                        >
                            {groups.map((g, index) => (
                                <button
                                    key={g.category?.id ?? 'other'}
                                    type="button"
                                    role="tab"
                                    id={`${id}-tab-${index}`}
                                    aria-selected={index === current}
                                    aria-controls={`${id}-panel`}
                                    tabIndex={index === current ? 0 : -1}
                                    onClick={() => setActive(index)}
                                    className={cn(
                                        'shrink-0 rounded-full border px-3 py-1.5 text-sm font-medium transition-colors outline-none focus-visible:ring-2 focus-visible:ring-[var(--site-accent)]/50',
                                        index === current
                                            ? 'border-transparent bg-[var(--site-accent)] text-[var(--site-accent-fg)]'
                                            : 'bg-card text-muted-foreground hover:text-foreground',
                                    )}
                                >
                                    {label(g)}
                                </button>
                            ))}
                        </div>
                    )}
                    <div
                        id={`${id}-panel`}
                        role={groups.length > 1 ? 'tabpanel' : undefined}
                        aria-labelledby={
                            groups.length > 1
                                ? `${id}-tab-${current}`
                                : undefined
                        }
                        className="grid gap-4 sm:grid-cols-2 xl:grid-cols-3"
                    >
                        {group.posts.map((post) => (
                            <BlogCard
                                key={post.id}
                                post={post}
                                timezone={site.timezone}
                            />
                        ))}
                    </div>
                </>
            )}
        </section>
    );
}
