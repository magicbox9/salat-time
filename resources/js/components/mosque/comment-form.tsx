import { Send } from 'lucide-react';
import { useId, useState } from 'react';
import { toast } from 'sonner';
import InputError from '@/components/input-error';
import { Button } from '@/components/ui/button';
import { useT } from '@/lib/i18n';
import { ApiError, api, errorMessage } from './api';
import type { PostComment } from './types';

const MIN = 2;
const MAX = 1000;

/** Writing a comment (signed-in visitors with a verified email). */
export function CommentForm({
    url,
    onPosted,
}: {
    url: string;
    onPosted: (comment: PostComment) => void;
}) {
    const t = useT();
    const id = useId();
    const [body, setBody] = useState('');
    const [error, setError] = useState<string | null>(null);
    const [sending, setSending] = useState(false);
    const length = body.trim().length;

    const submit = async (event: React.FormEvent) => {
        event.preventDefault();

        if (length < MIN || length > MAX) {
            setError(t('mosque.comment_length', { min: MIN, max: MAX }));

            return;
        }

        setSending(true);
        setError(null);

        try {
            const { comment } = await api<{ comment: PostComment }>(
                'POST',
                url,
                { body: body.trim() },
            );
            onPosted(comment);
            setBody('');
            toast.success(t('mosque.comment_posted'));
        } catch (caught) {
            const message = errorMessage(caught, t);

            if (caught instanceof ApiError && caught.status === 422) {
                setError(message);
            } else {
                toast.error(message);
            }
        } finally {
            setSending(false);
        }
    };

    return (
        <form onSubmit={submit} className="space-y-1.5">
            <label htmlFor={id} className="sr-only">
                {t('mosque.your_comment')}
            </label>
            <div className="flex items-end gap-2">
                <textarea
                    id={id}
                    value={body}
                    onChange={(event) => setBody(event.target.value)}
                    maxLength={MAX}
                    rows={2}
                    placeholder={t('mosque.comment_placeholder')}
                    aria-invalid={error ? true : undefined}
                    className="min-h-[2.75rem] flex-1 resize-y rounded-xl border border-input bg-transparent px-3 py-2 text-sm shadow-xs outline-none placeholder:text-muted-foreground focus-visible:border-ring focus-visible:ring-[3px] focus-visible:ring-ring/50 aria-invalid:border-destructive"
                />
                <Button
                    type="submit"
                    size="icon"
                    disabled={sending || length < MIN}
                    aria-label={t('mosque.send')}
                >
                    <Send className="size-4 rtl:-scale-x-100" />
                </Button>
            </div>
            <div className="flex justify-between gap-2">
                <InputError message={error ?? undefined} />
                <span
                    className="ms-auto text-xs text-muted-foreground tabular-nums"
                    dir="ltr"
                >
                    {length}/{MAX}
                </span>
            </div>
        </form>
    );
}
