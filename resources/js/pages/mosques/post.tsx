import { Link, usePage } from '@inertiajs/react';
import { PencilLine, UserRound } from 'lucide-react';
import { MarkdownContent } from '@/components/markdown-content';
import {
    ArticleAttachment,
    ArticleNeighbours,
    ShareButton,
} from '@/components/mosque/article-parts';
import { ArticleVideo } from '@/components/mosque/article-video';
import { EventWhen } from '@/components/mosque/blog-card';
import { formatInstant } from '@/components/mosque/calendar';
import { PostComments } from '@/components/mosque/post-comments';
import { PreviewNotice } from '@/components/mosque/preview-notice';
import { SiteHead } from '@/components/mosque/site-head';
import { MosqueSiteShell } from '@/components/mosque/site-shell';
import type {
    ArticleData,
    Neighbour,
    SiteMeta,
    SiteShell,
} from '@/components/mosque/site-types';
import type { MosqueViewer } from '@/components/mosque/types';
import { Button } from '@/components/ui/button';
import { useT } from '@/lib/i18n';

type Props = {
    site: SiteShell;
    post: ArticleData;
    neighbours: { previous: Neighbour; next: Neighbour };
    viewer: MosqueViewer;
    shareUrl: string;
    meta: SiteMeta;
};

/** One article of a mosque's blog: a khutbah, a piece of news, an event… */
export default function MosquePostPage({
    site,
    post,
    neighbours,
    viewer,
    shareUrl,
    meta,
}: Props) {
    const t = useT();
    const { locale } = usePage().props;
    const editUrl = `/manage/${site.slug}/posts/${post.id}/edit`;
    const khutbah = post.category?.slug === 'khutbah';

    return (
        <>
            <SiteHead meta={meta} />
            <MosqueSiteShell site={site} current={khutbah ? 'khutbah' : 'blog'}>
                <article
                    className="mx-auto max-w-3xl space-y-6"
                    aria-labelledby="post-title"
                >
                    {post.status !== 'published' && (
                        <PreviewNotice
                            editUrl={editUrl}
                            message={
                                post.status === 'scheduled'
                                    ? t('mosquesite.preview_scheduled')
                                    : t('mosquesite.preview_draft')
                            }
                        />
                    )}

                    <header className="space-y-4">
                        <p className="flex flex-wrap items-center gap-x-3 gap-y-1 text-sm text-muted-foreground">
                            {post.category && (
                                <Link
                                    href={`/mosques/${site.slug}/blog?category=${post.category.slug}`}
                                    className="inline-flex items-center gap-1.5 font-medium text-foreground hover:underline hover:underline-offset-4"
                                >
                                    <span
                                        aria-hidden
                                        className="size-2 rounded-full bg-[var(--site-accent)]"
                                    />
                                    {post.category.name}
                                </Link>
                            )}
                            {post.published_at && (
                                <time dateTime={post.published_at}>
                                    {formatInstant(
                                        post.published_at,
                                        locale,
                                        site.timezone,
                                        { dateStyle: 'long' },
                                    )}
                                </time>
                            )}
                            {post.author && (
                                <span className="inline-flex items-center gap-1">
                                    <UserRound
                                        className="size-3.5"
                                        aria-hidden
                                    />
                                    {post.author}
                                </span>
                            )}
                        </p>
                        <h1
                            id="post-title"
                            dir="auto"
                            className="text-3xl leading-tight font-semibold tracking-tight text-balance sm:text-4xl"
                        >
                            {post.title}
                        </h1>
                        {post.excerpt && (
                            <p
                                dir="auto"
                                className="text-lg leading-relaxed text-muted-foreground"
                            >
                                {post.excerpt}
                            </p>
                        )}
                        <div className="flex flex-wrap items-center gap-2">
                            {post.event_starts_at && (
                                <EventWhen
                                    iso={post.event_starts_at}
                                    timezone={site.timezone}
                                    className="text-sm"
                                />
                            )}
                            <span className="ms-auto flex gap-2">
                                {viewer.can_manage && (
                                    <Button asChild size="sm" variant="ghost">
                                        <Link href={editUrl}>
                                            <PencilLine
                                                className="size-4"
                                                aria-hidden
                                            />
                                            {t('manage.edit')}
                                        </Link>
                                    </Button>
                                )}
                                <ShareButton
                                    url={shareUrl}
                                    title={post.title}
                                />
                            </span>
                        </div>
                    </header>

                    {post.video ? (
                        <ArticleVideo
                            video={post.video}
                            title={post.title}
                            poster={post.image_url}
                        />
                    ) : (
                        post.image_url && (
                            <img
                                src={post.image_url}
                                alt=""
                                className="max-h-[32rem] w-full rounded-2xl bg-muted object-cover shadow-xs"
                            />
                        )
                    )}

                    <MarkdownContent
                        html={post.body_html}
                        className="text-base text-foreground/90 sm:text-[1.0625rem]"
                    />

                    {post.attachment && (
                        <ArticleAttachment file={post.attachment} />
                    )}

                    {post.status === 'published' && (
                        <div
                            className="rounded-2xl border bg-card p-4 shadow-xs sm:p-5"
                            id="comments"
                        >
                            <PostComments
                                slug={site.slug}
                                postId={post.id}
                                initialCount={post.comments_count}
                                viewer={viewer}
                            />
                        </div>
                    )}

                    <ArticleNeighbours
                        previous={neighbours.previous}
                        next={neighbours.next}
                    />
                </article>
            </MosqueSiteShell>
        </>
    );
}
