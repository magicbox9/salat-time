import { useForm } from '@inertiajs/react';
import InputError from '@/components/input-error';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { Spinner } from '@/components/ui/spinner';
import { useT } from '@/lib/i18n';
import { cn } from '@/lib/utils';

export type ManagedMessage = {
    id: number;
    body: string;
    /** "Y-m-dTH:i" in the mosque's time zone. */
    starts_at: string | null;
    ends_at: string | null;
    active: boolean;
    state: 'live' | 'scheduled' | 'ended' | 'paused';
};

const MAX = 500;

/** Writing a new screen message, or editing one. */
export function MessageForm({
    slug,
    timezone,
    message,
    onDone,
}: {
    slug: string;
    timezone: string;
    message?: ManagedMessage;
    onDone?: () => void;
}) {
    const t = useT();
    const form = useForm({
        body: message?.body ?? '',
        starts_at: message?.starts_at ?? '',
        ends_at: message?.ends_at ?? '',
        active: message?.active ?? true,
    });
    const { data, setData, errors, processing } = form;

    const submit = (event: React.FormEvent) => {
        event.preventDefault();
        form.transform((current) => ({
            ...current,
            starts_at: current.starts_at || null,
            ends_at: current.ends_at || null,
        }));
        const options = {
            preserveScroll: true,
            onSuccess: () => {
                if (!message) {
                    form.reset();
                }

                onDone?.();
            },
        };

        if (message) {
            form.put(`/manage/${slug}/display/messages/${message.id}`, options);
        } else {
            form.post(`/manage/${slug}/display/messages`, options);
        }
    };

    const id = message ? `message-${message.id}` : 'message-new';

    return (
        <form onSubmit={submit} className="grid gap-3">
            <div className="grid gap-1.5">
                <Label
                    htmlFor={`${id}-body`}
                    className={cn(message && 'sr-only')}
                >
                    {t('display.message_body')}
                </Label>
                <textarea
                    id={`${id}-body`}
                    dir="auto"
                    rows={3}
                    maxLength={MAX}
                    value={data.body}
                    onChange={(event) => setData('body', event.target.value)}
                    placeholder={t('display.message_placeholder')}
                    aria-invalid={errors.body ? true : undefined}
                    className="min-h-20 w-full rounded-md border border-input bg-transparent px-3 py-2 text-base shadow-xs outline-none placeholder:text-muted-foreground focus-visible:border-ring focus-visible:ring-[3px] focus-visible:ring-ring/50 aria-invalid:border-destructive md:text-sm"
                />
                <div className="flex justify-between gap-3 text-xs text-muted-foreground">
                    <InputError message={errors.body} />
                    <span className="ms-auto tabular-nums" dir="ltr">
                        {data.body.length}/{MAX}
                    </span>
                </div>
            </div>
            <div className="grid gap-3 sm:grid-cols-2">
                <div className="grid gap-1.5">
                    <Label htmlFor={`${id}-start`}>
                        {t('display.message_starts')}
                    </Label>
                    <Input
                        id={`${id}-start`}
                        type="datetime-local"
                        dir="ltr"
                        value={data.starts_at}
                        onChange={(event) =>
                            setData('starts_at', event.target.value)
                        }
                    />
                    <InputError message={errors.starts_at} />
                </div>
                <div className="grid gap-1.5">
                    <Label htmlFor={`${id}-end`}>
                        {t('display.message_ends')}
                    </Label>
                    <Input
                        id={`${id}-end`}
                        type="datetime-local"
                        dir="ltr"
                        value={data.ends_at}
                        onChange={(event) =>
                            setData('ends_at', event.target.value)
                        }
                    />
                    <InputError message={errors.ends_at} />
                </div>
            </div>
            <p className="text-xs text-muted-foreground">
                {t('display.message_dates_hint', { timezone })}
            </p>
            <div className="flex justify-end gap-2">
                {onDone && message && (
                    <Button
                        type="button"
                        variant="ghost"
                        size="sm"
                        onClick={onDone}
                    >
                        {t('display.cancel')}
                    </Button>
                )}
                <Button
                    type="submit"
                    size="sm"
                    disabled={processing || data.body.trim() === ''}
                >
                    {processing && <Spinner />}
                    {message
                        ? t('display.message_save')
                        : t('display.message_add')}
                </Button>
            </div>
        </form>
    );
}
