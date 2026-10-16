import { usePage } from '@inertiajs/react';
import { CalendarDays, Pin } from 'lucide-react';
import { useState } from 'react';
import { Button } from '@/components/ui/button';
import { useT } from '@/lib/i18n';
import { cn } from '@/lib/utils';
import { formatInstant } from './calendar';
import { LinkedText } from './linked-text';
import { PostComments } from './post-comments';
import { PostTypeBadge, timeAgo } from './post-type-badge';
import type { MosquePost, MosqueViewer } from './types';

const PREVIEW = 600;

/** The first ~600 characters, cut between words (so links stay whole) and never inside an emoji. */
function preview(text: string): string | null {
    const chars = Array.from(text);

    if (chars.length <= PREVIEW) {
        return null;
    }

    const head = chars.slice(0, PREVIEW).join('');
    const lastSpace = head.search(/\s\S*$/);

    return `${(lastSpace > PREVIEW / 2 ? head.slice(0, lastSpace) : head).trimEnd()}…`;
}

type Props = {
    post: MosquePost;
    slug: string;
    timezone: string;
    viewer: MosqueViewer;
};

/** One post of a mosque's feed. */
export function PostCard({ post, slug, timezone, viewer }: Props) {
    const t = useT();
    const { locale } = usePage().props;
    const [expanded, setExpanded] = useState(false);
    const short = preview(post.body);
    const long = short !== null;
    const body = short !== null && !expanded ? short : post.body;

    return (
        <article
            className={cn(
                'overflow-hidden rounded-2xl border bg-card shadow-xs',
                post.pinned && 'border-gold/50',
                post.type === 'janaza' && 'bg-muted/30',
            )}
            aria-labelledby={`post-${post.id}`}
        >
            {post.image_url && (
                <img
                    src={post.image_url}
                    alt=""
                    loading="lazy"
                    className="max-h-96 w-full bg-muted object-cover"
                />
            )}
            <div className="space-y-3 p-4 sm:p-5">
                <div className="flex flex-wrap items-center gap-2 text-xs text-muted-foreground">
                    <PostTypeBadge type={post.type} />
                    {post.pinned && (
                        <span className="inline-flex items-center gap-1 font-medium text-foreground">
                            <Pin className="size-3.5 text-gold" />
                            {t('mosque.pinned')}
                        </span>
                    )}
                    {post.published_at && (
                        <time
                            dateTime={post.published_at}
                            title={formatInstant(
                                post.published_at,
                                locale,
                                timezone,
                                {
                                    dateStyle: 'full',
                                    timeStyle: 'short',
                                },
                            )}
                        >
                            {timeAgo(post.published_at, locale)}
                        </time>
                    )}
                </div>

                <h3
                    id={`post-${post.id}`}
                    className="text-lg leading-snug font-semibold break-words"
                >
                    {post.title}
                </h3>

                {post.type === 'event' && post.event_starts_at && (
                    <p className="inline-flex items-center gap-2 rounded-lg bg-sky-500/10 px-3 py-1.5 text-sm font-medium text-sky-800 dark:text-sky-200">
                        <CalendarDays className="size-4" />
                        {formatInstant(post.event_starts_at, locale, timezone, {
                            weekday: 'long',
                            day: 'numeric',
                            month: 'long',
                            year: 'numeric',
                            hour: '2-digit',
                            minute: '2-digit',
                        })}
                    </p>
                )}

                <LinkedText
                    text={body}
                    className="text-sm leading-relaxed text-foreground/90"
                />
                {long && (
                    <Button
                        variant="link"
                        size="sm"
                        className="h-auto px-0"
                        onClick={() => setExpanded(!expanded)}
                    >
                        {expanded
                            ? t('mosque.show_less')
                            : t('mosque.read_more')}
                    </Button>
                )}

                <PostComments
                    slug={slug}
                    postId={post.id}
                    initialCount={post.comments_count}
                    viewer={viewer}
                />
            </div>
        </article>
    );
}
