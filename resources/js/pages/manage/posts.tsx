import { Link, usePage } from '@inertiajs/react';
import { MessageCircle, PencilLine, Pin, Plus } from 'lucide-react';
import { formatInstant } from '@/components/mosque/calendar';
import { PostTypeBadge } from '@/components/mosque/post-type-badge';
import type { MosquePost } from '@/components/mosque/types';
import { ConfirmDelete } from '@/components/manage/confirm-delete';
import { ManageHeader } from '@/components/manage/manage-header';
import { Pager } from '@/components/manage/pager';
import type { Paginated } from '@/components/manage/pager';
import { Button } from '@/components/ui/button';
import { useT } from '@/lib/i18n';
import { cn } from '@/lib/utils';
import type { MosqueSummary } from '@/types/mosque';

type ManagedPost = MosquePost & { updated_at: string | null };

type Props = {
    mosque: MosqueSummary;
    posts: Paginated<ManagedPost>;
    status: 'all' | 'drafts' | 'published';
};

/** A mosque's posts, drafts included. */
export default function ManagePosts({ mosque, posts, status }: Props) {
    const t = useT();
    const { locale } = usePage().props;
    const base = `/manage/${mosque.slug}/posts`;
    const filters: Props['status'][] = ['all', 'published', 'drafts'];

    return (
        <div className="mx-auto max-w-4xl space-y-6">
            <ManageHeader
                mosque={mosque}
                title={t('manage.posts_title')}
                description={t('manage.posts_intro')}
                actions={
                    <Button asChild>
                        <Link href={`${base}/create`}>
                            <Plus className="size-4" />
                            {t('manage.new_post')}
                        </Link>
                    </Button>
                }
            />

            <div className="flex gap-1 rounded-xl bg-muted p-1 sm:w-fit">
                {filters.map((filter) => (
                    <Link
                        key={filter}
                        href={
                            filter === 'all' ? base : `${base}?status=${filter}`
                        }
                        preserveScroll
                        aria-current={filter === status ? 'page' : undefined}
                        className={cn(
                            'flex-1 rounded-lg px-3 py-1.5 text-center text-sm font-medium transition-colors',
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
                                    <PostTypeBadge type={post.type} />
                                    {post.published_at ? (
                                        <span>
                                            {t('manage.published_on', {
                                                date: formatInstant(
                                                    post.published_at,
                                                    locale,
                                                    mosque.timezone,
                                                ),
                                            })}
                                        </span>
                                    ) : (
                                        <span className="rounded-full bg-gold/20 px-2 py-0.5 font-medium text-foreground">
                                            {t('manage.draft')}
                                        </span>
                                    )}
                                    {post.pinned && (
                                        <span className="inline-flex items-center gap-1">
                                            <Pin className="size-3.5 text-gold" />
                                            {t('manage.pinned')}
                                        </span>
                                    )}
                                    <span className="inline-flex items-center gap-1">
                                        <MessageCircle className="size-3.5" />
                                        <span className="tabular-nums">
                                            {post.comments_count}
                                        </span>
                                    </span>
                                </div>
                                <p className="mt-1 truncate font-medium">
                                    {post.title}
                                </p>
                            </div>
                            <div className="flex shrink-0 items-center gap-1">
                                <Button asChild variant="outline" size="sm">
                                    <Link href={`${base}/${post.id}/edit`}>
                                        <PencilLine className="size-4" />
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
        </div>
    );
}
