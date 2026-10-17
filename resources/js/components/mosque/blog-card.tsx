import { Link, usePage } from '@inertiajs/react';
import {
    CalendarDays,
    FileText,
    MessageCircle,
    Pin,
    CirclePlay,
} from 'lucide-react';
import { useT } from '@/lib/i18n';
import { cn } from '@/lib/utils';
import { formatInstant } from './calendar';
import type { PostCardData } from './site-types';

type Props = {
    post: PostCardData;
    timezone: string;
    /** "row": thumbnail beside the text (home lists). */
    layout?: 'card' | 'row';
    className?: string;
};

export function PostDate({
    iso,
    timezone,
    className,
}: {
    iso: string;
    timezone: string;
    className?: string;
}) {
    const { locale } = usePage().props;

    return (
        <time dateTime={iso} className={className}>
            {formatInstant(iso, locale, timezone, { dateStyle: 'medium' })}
        </time>
    );
}

export function EventWhen({
    iso,
    timezone,
    className,
}: {
    iso: string;
    timezone: string;
    className?: string;
}) {
    const { locale } = usePage().props;

    return (
        <span
            className={cn(
                'inline-flex items-center gap-1.5 rounded-lg bg-sky-500/10 px-2 py-1 text-xs font-medium text-sky-800 dark:text-sky-200',
                className,
            )}
        >
            <CalendarDays className="size-3.5" aria-hidden />
            <time dateTime={iso}>
                {formatInstant(iso, locale, timezone, {
                    weekday: 'short',
                    day: 'numeric',
                    month: 'short',
                    hour: '2-digit',
                    minute: '2-digit',
                })}
            </time>
        </span>
    );
}

/** A green-and-gold placeholder where a post has no picture. */
function CoverPlaceholder({ title }: { title: string }) {
    return (
        <div className="flex h-full w-full items-center justify-center bg-gradient-to-br from-[var(--site-accent)] via-[color-mix(in_oklab,var(--site-accent)_75%,black)] to-[color-mix(in_oklab,var(--site-accent)_55%,black)]">
            <span
                aria-hidden
                className="text-3xl font-semibold text-[var(--site-accent-fg)] opacity-80"
            >
                {Array.from(title.trim())[0]?.toUpperCase() ?? '•'}
            </span>
        </div>
    );
}

/** One post of the blog, as a card (cover, category, date, title, excerpt). */
export function BlogCard({
    post,
    timezone,
    layout = 'card',
    className,
}: Props) {
    const t = useT();
    const row = layout === 'row';

    return (
        <article
            className={cn(
                'group relative flex overflow-hidden rounded-2xl border bg-card shadow-xs transition-[border-color,box-shadow] focus-within:ring-2 focus-within:ring-[var(--site-accent)]/50 hover:border-[var(--site-accent)]/40 hover:shadow-md',
                row ? 'flex-row gap-0' : 'flex-col',
                post.pinned && 'border-gold/50',
                className,
            )}
        >
            <div
                className={cn(
                    'shrink-0 overflow-hidden bg-muted',
                    row ? 'w-24 sm:w-32' : 'aspect-[16/9] w-full',
                )}
            >
                {post.image_url ? (
                    <img
                        src={post.image_url}
                        alt=""
                        loading="lazy"
                        className="h-full w-full object-cover transition-transform duration-500 motion-safe:group-hover:scale-[1.03]"
                    />
                ) : (
                    <CoverPlaceholder title={post.title} />
                )}
            </div>
            <div
                className={cn(
                    'flex min-w-0 flex-1 flex-col',
                    row ? 'p-3 sm:p-4' : 'p-4 sm:p-5',
                )}
            >
                <p className="flex flex-wrap items-center gap-x-2 gap-y-1 text-xs text-muted-foreground">
                    {post.category && (
                        <span className="inline-flex items-center gap-1.5 font-medium text-foreground">
                            <span
                                aria-hidden
                                className="size-1.5 rounded-full bg-[var(--site-accent)]"
                            />
                            {post.category.name}
                        </span>
                    )}
                    {post.pinned && (
                        <span className="inline-flex items-center gap-1 font-medium text-foreground">
                            <Pin className="size-3 text-gold" aria-hidden />
                            {t('mosque.pinned')}
                        </span>
                    )}
                    {post.published_at && (
                        <PostDate iso={post.published_at} timezone={timezone} />
                    )}
                </p>
                <h3
                    dir="auto"
                    className={cn(
                        'mt-1.5 leading-snug font-semibold break-words',
                        row
                            ? 'line-clamp-2 text-sm sm:text-base'
                            : 'line-clamp-2 text-lg',
                    )}
                >
                    <Link
                        href={post.url}
                        className="outline-none after:absolute after:inset-0 after:content-['']"
                    >
                        {post.title}
                    </Link>
                </h3>
                {post.excerpt && !row && (
                    <p
                        dir="auto"
                        className="mt-2 line-clamp-3 text-sm text-muted-foreground"
                    >
                        {post.excerpt}
                    </p>
                )}
                <div className="mt-auto flex flex-wrap items-center gap-2 pt-3 text-xs text-muted-foreground">
                    {post.event_starts_at && (
                        <EventWhen
                            iso={post.event_starts_at}
                            timezone={timezone}
                        />
                    )}
                    {post.has_video && (
                        <span
                            className="inline-flex items-center gap-1"
                            title={t('mosquesite.has_video')}
                        >
                            <CirclePlay className="size-3.5" aria-hidden />
                            <span className="sr-only sm:not-sr-only">
                                {t('mosquesite.video')}
                            </span>
                        </span>
                    )}
                    {post.has_attachment && (
                        <span
                            className="inline-flex items-center gap-1"
                            title={t('mosquesite.has_pdf')}
                        >
                            <FileText className="size-3.5" aria-hidden />
                            <span className="sr-only sm:not-sr-only">PDF</span>
                        </span>
                    )}
                    {post.comments_count > 0 && (
                        <span className="inline-flex items-center gap-1">
                            <MessageCircle className="size-3.5" aria-hidden />
                            <span className="tabular-nums">
                                {post.comments_count}
                            </span>
                            <span className="sr-only">
                                {t('mosquesite.comments')}
                            </span>
                        </span>
                    )}
                </div>
            </div>
        </article>
    );
}
