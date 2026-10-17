import { Link } from '@inertiajs/react';
import { MessageCircle } from 'lucide-react';
import { useState } from 'react';
import { toast } from 'sonner';
import { Button } from '@/components/ui/button';
import { Spinner } from '@/components/ui/spinner';
import { useT } from '@/lib/i18n';
import { useSignInUrl } from '@/lib/sign-in';
import { api, errorMessage } from './api';
import { CommentForm } from './comment-form';
import { CommentItem } from './comment-item';
import type { CursorPage, MosqueViewer, PostComment } from './types';

type Props = {
    slug: string;
    postId: number;
    initialCount: number;
    viewer: MosqueViewer;
};

/** Comments under a post, loaded when the visitor opens them. */
export function PostComments({ slug, postId, initialCount, viewer }: Props) {
    const t = useT();
    const signIn = useSignInUrl();
    const base = `/mosques/${slug}/posts/${postId}/comments`;
    const [open, setOpen] = useState(false);
    const [count, setCount] = useState(initialCount);
    const [comments, setComments] = useState<PostComment[]>([]);
    const [cursor, setCursor] = useState<string | null>(null);
    const [loading, setLoading] = useState(false);
    const [busyId, setBusyId] = useState<number | null>(null);

    const load = async (next: string | null) => {
        setLoading(true);

        try {
            const page = await api<CursorPage<PostComment>>(
                'GET',
                next ? `${base}?cursor=${encodeURIComponent(next)}` : base,
            );
            setComments((current) => {
                const known = new Set(current.map((c) => c.id));

                return [
                    ...current,
                    ...page.data.filter((c) => !known.has(c.id)),
                ];
            });
            setCursor(page.next_cursor);
        } catch (error) {
            toast.error(errorMessage(error, t));
        } finally {
            setLoading(false);
        }
    };

    const toggle = () => {
        setOpen(!open);

        if (!open && comments.length === 0 && count > 0) {
            void load(null);
        }
    };

    const act = async (comment: PostComment, run: () => Promise<void>) => {
        setBusyId(comment.id);

        try {
            await run();
        } catch (error) {
            toast.error(errorMessage(error, t));
        } finally {
            setBusyId(null);
        }
    };

    const remove = (comment: PostComment) =>
        act(comment, async () => {
            if (!window.confirm(t('mosque.delete_comment_confirm'))) {
                return;
            }

            await api('DELETE', `/comments/${comment.id}`);
            setComments((list) => list.filter((c) => c.id !== comment.id));
            setCount((c) => Math.max(0, c - 1));
            toast.success(t('mosque.comment_deleted'));
        });

    const toggleHidden = (comment: PostComment) =>
        act(comment, async () => {
            const { comment: updated } = await api<{ comment: PostComment }>(
                'PATCH',
                `/comments/${comment.id}/${comment.hidden ? 'unhide' : 'hide'}`,
            );
            setComments((list) =>
                list.map((c) => (c.id === updated.id ? updated : c)),
            );
        });

    return (
        <div className="border-t pt-3">
            <Button
                variant="ghost"
                size="sm"
                className="-ms-2 text-muted-foreground"
                aria-expanded={open}
                onClick={toggle}
            >
                <MessageCircle className="size-4" />
                {count > 0
                    ? t('mosque.comments_count', { count })
                    : t('mosque.comment_action')}
            </Button>

            {open && (
                <div className="mt-3 space-y-4">
                    {comments.length > 0 && (
                        <ul className="space-y-3">
                            {comments.map((comment) => (
                                <CommentItem
                                    key={comment.id}
                                    comment={comment}
                                    busy={busyId === comment.id}
                                    onDelete={() => remove(comment)}
                                    onToggleHidden={() => toggleHidden(comment)}
                                />
                            ))}
                        </ul>
                    )}
                    {loading && <Spinner className="mx-auto" />}
                    {cursor && !loading && (
                        <Button
                            variant="link"
                            size="sm"
                            onClick={() => load(cursor)}
                        >
                            {t('mosque.more_comments')}
                        </Button>
                    )}

                    {viewer.verified ? (
                        <CommentForm
                            url={base}
                            onPosted={(comment) => {
                                setComments((list) => [...list, comment]);
                                setCount((c) => c + 1);
                            }}
                        />
                    ) : (
                        <p className="rounded-lg bg-muted px-3 py-2 text-sm text-muted-foreground">
                            {viewer.signed_in ? (
                                <Link
                                    href="/email/verify"
                                    className="font-medium text-primary hover:underline"
                                >
                                    {t('mosque.verify_to_comment')}
                                </Link>
                            ) : (
                                <Link
                                    href={signIn}
                                    className="font-medium text-primary hover:underline"
                                >
                                    {t('mosque.login_to_comment')}
                                </Link>
                            )}
                        </p>
                    )}
                </div>
            )}
        </div>
    );
}
