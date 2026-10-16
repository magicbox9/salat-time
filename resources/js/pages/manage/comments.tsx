import { Link, router, usePage } from '@inertiajs/react';
import { Eye, EyeOff } from 'lucide-react';
import { useState } from 'react';
import { ManageHeader } from '@/components/manage/manage-header';
import { Pager } from '@/components/manage/pager';
import type { Paginated } from '@/components/manage/pager';
import { timeAgo } from '@/components/mosque/post-type-badge';
import type { PostComment } from '@/components/mosque/types';
import { Button } from '@/components/ui/button';
import { useT } from '@/lib/i18n';
import { cn } from '@/lib/utils';
import type { MosqueSummary } from '@/types/mosque';

type ModeratedComment = PostComment & { post: { id: number; title: string } };

type Props = {
    mosque: MosqueSummary;
    comments: Paginated<ModeratedComment>;
    filter: 'all' | 'hidden';
};

/** Every comment under the mosque's posts; hide what does not belong, restore by mistake. */
export default function ManageComments({ mosque, comments, filter }: Props) {
    const t = useT();
    const { locale } = usePage().props;
    const [busy, setBusy] = useState<number | null>(null);
    const base = `/manage/${mosque.slug}/comments`;

    const toggle = (comment: ModeratedComment) =>
        router.patch(
            `/comments/${comment.id}/${comment.hidden ? 'unhide' : 'hide'}`,
            {},
            {
                preserveScroll: true,
                onStart: () => setBusy(comment.id),
                onFinish: () => setBusy(null),
            },
        );

    return (
        <div className="mx-auto max-w-4xl space-y-6">
            <ManageHeader
                mosque={mosque}
                title={t('manage.comments_title')}
                description={t('manage.comments_intro')}
            />

            <div className="flex gap-1 rounded-xl bg-muted p-1 sm:w-fit">
                {(['all', 'hidden'] as const).map((value) => (
                    <Link
                        key={value}
                        href={value === 'all' ? base : `${base}?filter=hidden`}
                        preserveScroll
                        aria-current={value === filter ? 'page' : undefined}
                        className={cn(
                            'flex-1 rounded-lg px-3 py-1.5 text-center text-sm font-medium transition-colors',
                            value === filter
                                ? 'bg-background shadow-sm'
                                : 'text-muted-foreground hover:text-foreground',
                        )}
                    >
                        {t(`manage.comments_filter_${value}`)}
                    </Link>
                ))}
            </div>

            {comments.data.length === 0 ? (
                <div className="rounded-2xl border border-dashed px-6 py-12 text-center text-sm text-muted-foreground">
                    {filter === 'hidden'
                        ? t('manage.no_hidden_comments')
                        : t('manage.no_comments')}
                </div>
            ) : (
                <ul className="divide-y rounded-2xl border bg-card shadow-xs">
                    {comments.data.map((comment) => (
                        <li
                            key={comment.id}
                            className={cn(
                                'flex flex-col gap-3 p-4 sm:flex-row sm:items-start',
                                comment.hidden && 'bg-muted/40',
                            )}
                        >
                            <div className="min-w-0 flex-1">
                                <p className="flex flex-wrap items-center gap-x-2 text-xs text-muted-foreground">
                                    <span className="font-semibold text-foreground">
                                        {comment.author}
                                    </span>
                                    {comment.created_at && (
                                        <time dateTime={comment.created_at}>
                                            {timeAgo(
                                                comment.created_at,
                                                locale,
                                            )}
                                        </time>
                                    )}
                                    {comment.hidden && (
                                        <span className="rounded-full bg-muted px-2 py-0.5 font-medium uppercase">
                                            {t('mosque.hidden')}
                                        </span>
                                    )}
                                </p>
                                <p className="mt-1 text-sm break-words whitespace-pre-line">
                                    {comment.body}
                                </p>
                                <p className="mt-1 truncate text-xs text-muted-foreground">
                                    {t('manage.on_post', {
                                        title: comment.post.title,
                                    })}
                                </p>
                            </div>
                            <Button
                                variant={comment.hidden ? 'outline' : 'ghost'}
                                size="sm"
                                disabled={busy === comment.id}
                                onClick={() => toggle(comment)}
                                className="shrink-0 self-start"
                            >
                                {comment.hidden ? (
                                    <Eye className="size-4" />
                                ) : (
                                    <EyeOff className="size-4" />
                                )}
                                {comment.hidden
                                    ? t('mosque.unhide')
                                    : t('mosque.hide')}
                            </Button>
                        </li>
                    ))}
                </ul>
            )}

            <Pager page={comments} />
        </div>
    );
}
