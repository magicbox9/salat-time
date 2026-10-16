import { Link, usePage } from '@inertiajs/react';
import { ArrowUpRight, Newspaper } from 'lucide-react';
import { useT } from '@/lib/i18n';
import { formatPostDate } from './format';
import type { HubPost } from './types';

/** The mosque's three latest published posts, linking to its site. */
export function LatestPosts({
    posts,
    mosqueSlug,
}: {
    posts: HubPost[];
    mosqueSlug: string;
}) {
    const t = useT();
    const { locale } = usePage().props;

    if (posts.length === 0) {
        return null;
    }

    return (
        <section aria-labelledby="hub-posts">
            <header className="mb-3 flex items-end justify-between gap-3">
                <h2
                    id="hub-posts"
                    className="flex items-center gap-2 text-lg font-semibold"
                >
                    <Newspaper className="size-4 text-primary" aria-hidden />
                    {t('hub.posts_title')}
                </h2>
                <Link
                    href={`/mosques/${encodeURIComponent(mosqueSlug)}/blog`}
                    className="flex items-center gap-1 text-sm text-primary hover:underline"
                >
                    {t('hub.posts_all')}
                    <ArrowUpRight
                        className="size-3.5 rtl:-scale-x-100"
                        aria-hidden
                    />
                </Link>
            </header>
            <ul className="grid gap-3 md:grid-cols-3">
                {posts.map((post) => (
                    <li key={post.id}>
                        <Link
                            href={post.url}
                            className="group flex h-full flex-col overflow-hidden rounded-2xl border bg-card transition-colors hover:border-primary/40"
                        >
                            {post.image_url && (
                                <img
                                    src={post.image_url}
                                    alt=""
                                    loading="lazy"
                                    className="aspect-[16/9] w-full object-cover transition-transform duration-500 motion-safe:group-hover:scale-[1.02]"
                                />
                            )}
                            <span className="flex flex-1 flex-col p-4">
                                <span className="flex flex-wrap items-center gap-x-2 text-xs text-muted-foreground">
                                    {(post.category ||
                                        post.type !== 'news') && (
                                        <span className="font-medium text-gold">
                                            {post.category ??
                                                t(`hub.post_type_${post.type}`)}
                                        </span>
                                    )}
                                    {post.published_at && (
                                        <time dateTime={post.published_at}>
                                            {formatPostDate(
                                                post.published_at,
                                                locale,
                                            )}
                                        </time>
                                    )}
                                </span>
                                <span
                                    dir="auto"
                                    className="mt-1.5 line-clamp-2 font-medium group-hover:underline group-hover:underline-offset-4"
                                >
                                    {post.title}
                                </span>
                                {post.excerpt && (
                                    <span
                                        dir="auto"
                                        className="mt-1.5 line-clamp-3 text-sm text-muted-foreground"
                                    >
                                        {post.excerpt}
                                    </span>
                                )}
                            </span>
                        </Link>
                    </li>
                ))}
            </ul>
        </section>
    );
}
