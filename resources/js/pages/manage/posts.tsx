import { Link, usePage } from '@inertiajs/react';
import {
    ExternalLink,
    MessageCircle,
    PencilLine,
    Pin,
    Plus,
} from 'lucide-react';
import { ConfirmDelete } from '@/components/manage/confirm-delete';
import { ManageLayout } from '@/components/manage/manage-layout';
import { Pager } from '@/components/manage/pager';
import type { Paginated } from '@/components/manage/pager';
import { StatusBadge } from '@/components/manage/status-badge';
import type { PublishStatus } from '@/components/manage/status-badge';
import { formatInstant } from '@/components/mosque/calendar';
import type { PostCategoryRef } from '@/components/mosque/site-types';
import type { MosquePost } from '@/components/mosque/types';
import { Button } from '@/components/ui/button';
import { useT } from '@/lib/i18n';
import { cn } from '@/lib/utils';
import type { MosqueSummary } from '@/types/mosque';

type ManagedPost = MosquePost & {
    category: PostCategoryRef | null;
    status: PublishStatus;
    updated_at: string | null;
};

type Filter = 'all' | 'published' | 'scheduled' | 'drafts';

type Props = {
    mosque: MosqueSummary;
    posts: Paginated<ManagedPost>;
    status: Filter;
};

/** A mosque's posts, drafts and scheduled ones included. */
export default function ManagePosts({ mosque, posts, status }: Props) {
    const t = useT();
    const { locale } = usePage().props;
    const base = `/manage/${mosque.slug}/posts`;
    const filters: Filter[] = ['all', 'published', 'scheduled', 'drafts'];

    return (
        <ManageLayout
            mosque={mosque}
            title={t('manage.posts_title')}
            description={t('manage.posts_intro')}
            actions={
                <Button asChild>
                    <Link href={`${base}/create`}>
                        <Plus className="size-4" aria-hidden />
                        {t('manage.new_post')}
                    </Link>
                </Button>
            }
        >
            <div className="flex gap-1 overflow-x-auto rounded-xl bg-muted p-1 sm:w-fit">
                {filters.map((filter) => (
                    <Link
                        key={filter}
                        href={
                            filter === 'all' ? base : `${base}?status=${filter}`
                        }
                        preserveScroll
                        aria-current={filter === status ? 'page' : undefined}
                        className={cn(
                            'flex-1 shrink-0 rounded-lg px-3 py-1.5 text-center text-sm font-medium whitespace-nowrap transition-colors',
                            filter === status
                                ? 'bg-background shadow-sm'
                                : 'text-muted-foreground hover:text-foreground',
                        )}
                    >
                        {t(`manage.filter_${filter}`)}
                    </Link>
                ))}
            </div>

            {posts.data.length === 0 ? (
                <div className="rounded-2xl border border-dashed px-6 py-12 text-center">
                    <p className="font-medium">{t('manage.no_posts')}</p>
                    <p className="mt-1 text-sm text-muted-foreground">
                        {t('manage.no_posts_hint')}
                    </p>
                </div>
            ) : (
                <ul className="divide-y rounded-2xl border bg-card shadow-xs">
                    {posts.data.map((post) => (
                        <li
                            key={post.id}
                            className="flex flex-col gap-3 p-4 sm:flex-row sm:items-center"
                        >
                            {post.image_url && (
                                <img
                                    src={post.image_url}
                                    alt=""
                                    className="hidden size-14 shrink-0 rounded-lg object-cover sm:block"
                                />
                            )}
                            <div className="min-w-0 flex-1">
                                <div className="flex flex-wrap items-center gap-2 text-xs text-muted-foreground">
                                    <StatusBadge status={post.status} />
                                    {post.category && (
                                        <span className="font-medium text-foreground">
                                            {post.category.name}
                                        </span>
                                    )}
                                    {post.published_at && (
                                        <span>
                                            {t(
                                                post.status === 'scheduled'
                                                    ? 'manage.scheduled_for'
                                                    : 'manage.published_on',
                                                {
                                                    date: formatInstant(
                                                        post.published_at,
                                                        locale,
                                                        mosque.timezone,
                                                        {
                                                            dateStyle: 'medium',
                                                            ...(post.status ===
                                                            'scheduled'
                                                                ? {
                                                                      timeStyle:
                                                                          'short',
                                                                  }
                                                                : {}),
                                                        },
                                                    ),
                                                },
                                            )}
                                        </span>
                                    )}
                                    {post.pinned && (
                                        <span className="inline-flex items-center gap-1">
                                            <Pin
                                                className="size-3.5 text-gold"
                                                aria-hidden
                                            />
                                            {t('manage.pinned')}
                                        </span>
                                    )}
                                    <span className="inline-flex items-center gap-1">
                                        <MessageCircle
                                            className="size-3.5"
                                            aria-hidden
                                        />
                                        <span className="tabular-nums">
                                            {post.comments_count}
                                        </span>
                                        <span className="sr-only">
                                            {t('manage.stat_comments')}
                                        </span>
                                    </span>
                                </div>
                                <p
                                    dir="auto"
                                    className="mt-1 truncate font-medium"
                                >
                                    {post.title}
                                </p>
                            </div>
                            <div className="flex shrink-0 items-center gap-1">
                                {post.url && (
                                    <Button
                                        asChild
                                        variant="ghost"
                                        size="icon"
                                        aria-label={t('manage.view_post')}
                                    >
                                        <Link href={post.url}>
                                            <ExternalLink className="size-4" />
                                        </Link>
                                    </Button>
                                )}
                                <Button asChild variant="outline" size="sm">
                                    <Link href={`${base}/${post.id}/edit`}>
                                        <PencilLine
                                            className="size-4"
                                            aria-hidden
                                        />
                                        {t('manage.edit')}
                                    </Link>
                                </Button>
                                <ConfirmDelete
                                    url={`${base}/${post.id}`}
                                    title={t('manage.delete_post_title')}
                                    description={t('manage.delete_post_body', {
                                        title: post.title,
                                    })}
                                    iconOnly
                                />
                            </div>
                        </li>
                    ))}
                </ul>
            )}

            <Pager page={posts} />
        </ManageLayout>
    );
}
