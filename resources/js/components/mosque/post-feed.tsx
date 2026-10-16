import { Link } from '@inertiajs/react';
import { Newspaper, Plus } from 'lucide-react';
import { useEffect, useState } from 'react';
import { toast } from 'sonner';
import { Button } from '@/components/ui/button';
import { Spinner } from '@/components/ui/spinner';
import { useT } from '@/lib/i18n';
import { api, errorMessage } from './api';
import { PostCard } from './post-card';
import type { CursorPage, MosquePost, MosqueViewer } from './types';

type Props = {
    slug: string;
    timezone: string;
    pinned: MosquePost[];
    feed: CursorPage<MosquePost>;
    viewer: MosqueViewer;
};

/** The mosque's news: pinned posts first, then the newest, "Load more" for older ones. */
export function PostFeed({ slug, timezone, pinned, feed, viewer }: Props) {
    const t = useT();
    const [posts, setPosts] = useState(feed.data);
    const [cursor, setCursor] = useState(feed.next_cursor);
    const [loading, setLoading] = useState(false);

    useEffect(() => {
        setPosts(feed.data);
        setCursor(feed.next_cursor);
    }, [feed]);

    const loadMore = async () => {
        if (!cursor) {
            return;
        }

        setLoading(true);

        try {
            const page = await api<CursorPage<MosquePost>>(
                'GET',
                `/mosques/${slug}/posts.json?cursor=${encodeURIComponent(cursor)}`,
            );
            setPosts((current) => {
                const known = new Set(current.map((p) => p.id));

                return [
                    ...current,
                    ...page.data.filter((p) => !known.has(p.id)),
                ];
            });
            setCursor(page.next_cursor);
        } catch (error) {
            toast.error(errorMessage(error, t));
        } finally {
            setLoading(false);
        }
    };

    const all = [...pinned, ...posts];

    return (
        <section aria-labelledby="mosque-news" className="space-y-4">
            <div className="flex items-center justify-between gap-3">
                <h2 id="mosque-news" className="text-lg font-semibold">
                    {t('mosque.news')}
                </h2>
                {viewer.can_manage && (
                    <Button asChild size="sm" variant="outline">
                        <Link href={`/manage/${slug}/posts/create`}>
                            <Plus className="size-4" />
                            {t('mosque.new_post')}
                        </Link>
                    </Button>
                )}
            </div>

            {all.length === 0 ? (
                <div className="rounded-2xl border border-dashed px-6 py-10 text-center">
                    <Newspaper className="mx-auto size-8 text-muted-foreground/60" />
                    <p className="mt-3 font-medium">{t('mosque.no_posts')}</p>
                    <p className="mt-1 text-sm text-muted-foreground">
                        {viewer.can_manage
                            ? t('mosque.no_posts_manager')
                            : t('mosque.no_posts_hint')}
                    </p>
                </div>
            ) : (
                <div className="space-y-4">
                    {all.map((post) => (
                        <PostCard
                            key={post.id}
                            post={post}
                            slug={slug}
                            timezone={timezone}
                            viewer={viewer}
                        />
                    ))}
                </div>
            )}

            {cursor && (
                <div className="flex justify-center">
                    <Button
                        variant="outline"
                        onClick={loadMore}
                        disabled={loading}
                    >
                        {loading && <Spinner />}
                        {t('mosque.load_more')}
                    </Button>
                </div>
            )}
        </section>
    );
}
