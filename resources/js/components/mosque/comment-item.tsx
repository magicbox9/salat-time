import { usePage } from '@inertiajs/react';
import { Eye, EyeOff, Trash2 } from 'lucide-react';
import { Avatar, AvatarFallback } from '@/components/ui/avatar';
import { Button } from '@/components/ui/button';
import { useInitials } from '@/hooks/use-initials';
import { useT } from '@/lib/i18n';
import { cn } from '@/lib/utils';
import { timeAgo } from './post-type-badge';
import type { PostComment } from './types';

type Props = {
    comment: PostComment;
    busy: boolean;
    onDelete: () => void;
    onToggleHidden: () => void;
};

/** One comment: plain text only; authors delete theirs, managers hide or restore. */
export function CommentItem({
    comment,
    busy,
    onDelete,
    onToggleHidden,
}: Props) {
    const t = useT();
    const { locale } = usePage().props;
    const initials = useInitials();

    return (
        <li className={cn('flex gap-3', comment.hidden && 'opacity-70')}>
            <Avatar className="size-8 shrink-0">
                <AvatarFallback className="bg-primary/10 text-xs text-primary">
                    {initials(comment.author || '?')}
                </AvatarFallback>
            </Avatar>
            <div className="min-w-0 flex-1">
                <div
                    className={cn(
                        'rounded-xl bg-muted/70 px-3 py-2',
                        comment.hidden &&
                            'border border-dashed border-muted-foreground/40 bg-transparent',
                    )}
                >
                    <p className="flex flex-wrap items-center gap-x-2 text-xs">
                        <span className="max-w-full truncate font-semibold text-foreground">
                            {comment.author}
                        </span>
                        {comment.created_at && (
                            <time
                                dateTime={comment.created_at}
                                className="text-muted-foreground"
                            >
                                {timeAgo(comment.created_at, locale)}
                            </time>
                        )}
                        {comment.hidden && (
                            <span className="rounded-full bg-muted px-2 py-0.5 text-[10px] font-medium text-muted-foreground uppercase">
                                {t('mosque.hidden')}
                            </span>
                        )}
                    </p>
                    <p className="mt-0.5 text-sm break-words whitespace-pre-line">
                        {comment.body}
                    </p>
                </div>
                {(comment.can_delete || comment.can_moderate) && (
                    <div className="mt-1 flex gap-1">
                        {comment.can_moderate && (
                            <Button
                                variant="ghost"
                                size="sm"
                                className="h-7 px-2 text-xs text-muted-foreground"
                                disabled={busy}
                                onClick={onToggleHidden}
                            >
                                {comment.hidden ? (
                                    <Eye className="size-3.5" />
                                ) : (
                                    <EyeOff className="size-3.5" />
                                )}
                                {comment.hidden
                                    ? t('mosque.unhide')
                                    : t('mosque.hide')}
                            </Button>
                        )}
                        {comment.can_delete && (
                            <Button
                                variant="ghost"
                                size="sm"
                                className="h-7 px-2 text-xs text-muted-foreground hover:text-destructive"
                                disabled={busy}
                                onClick={onDelete}
                            >
                                <Trash2 className="size-3.5" />
                                {t('mosque.delete')}
                            </Button>
                        )}
                    </div>
                )}
            </div>
        </li>
    );
}
