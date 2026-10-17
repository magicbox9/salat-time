import { router } from '@inertiajs/react';
import {
    ArrowDown,
    ArrowUp,
    Megaphone,
    Pause,
    Pencil,
    Play,
    Trash2,
} from 'lucide-react';
import { useState } from 'react';
import { Badge } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';
import { useT } from '@/lib/i18n';
import { cn } from '@/lib/utils';
import { Section } from './controls';
import type { ManagedMessage } from './message-form';
import { MessageForm } from './message-form';

type Props = {
    slug: string;
    timezone: string;
    messages: ManagedMessage[];
    max: number;
};

const STATE_STYLE: Record<ManagedMessage['state'], string> = {
    live: 'bg-primary/10 text-primary',
    scheduled: 'bg-gold/15 text-foreground',
    ended: 'bg-muted text-muted-foreground',
    paused: 'bg-muted text-muted-foreground',
};

/** The screen's messages: add, edit, pause, reorder and delete. */
export function MessagesEditor({ slug, timezone, messages, max }: Props) {
    const t = useT();
    const [editing, setEditing] = useState<number | null>(null);
    const [confirming, setConfirming] = useState<number | null>(null);
    const base = `/manage/${slug}/display/messages`;
    const options = { preserveScroll: true };

    const move = (index: number, by: -1 | 1) => {
        const ids = messages.map((m) => m.id);
        const target = index + by;

        if (target < 0 || target >= ids.length) {
            return;
        }

        [ids[index], ids[target]] = [ids[target], ids[index]];
        router.put(`${base}/order`, { ids }, options);
    };

    const toggle = (message: ManagedMessage) =>
        router.put(
            `${base}/${message.id}`,
            {
                body: message.body,
                starts_at: message.starts_at,
                ends_at: message.ends_at,
                active: !message.active,
            },
            options,
        );

    return (
        <Section
            id="messages"
            title={t('display.section_messages')}
            description={t('display.section_messages_hint')}
            icon={Megaphone}
        >
            {messages.length < max ? (
                <MessageForm slug={slug} timezone={timezone} />
            ) : (
                <p className="rounded-xl bg-muted px-4 py-3 text-sm text-muted-foreground">
                    {t('display.messages_full')}
                </p>
            )}

            {messages.length === 0 ? (
                <p className="text-sm text-muted-foreground">
                    {t('display.messages_empty')}
                </p>
            ) : (
                <ol className="grid gap-3">
                    {messages.map((message, index) => (
                        <li
                            key={message.id}
                            className={cn(
                                'rounded-xl border p-4',
                                !message.active && 'bg-muted/40',
                            )}
                        >
                            {editing === message.id ? (
                                <MessageForm
                                    slug={slug}
                                    timezone={timezone}
                                    message={message}
                                    onDone={() => setEditing(null)}
                                />
                            ) : (
                                <div className="flex flex-col gap-3 sm:flex-row sm:items-start">
                                    <div className="min-w-0 flex-1 space-y-2">
                                        <p
                                            dir="auto"
                                            className="text-sm leading-relaxed whitespace-pre-line"
                                        >
                                            {message.body}
                                        </p>
                                        <div className="flex flex-wrap items-center gap-2 text-xs text-muted-foreground">
                                            <Badge
                                                variant="outline"
                                                className={cn(
                                                    'border-transparent',
                                                    STATE_STYLE[message.state],
                                                )}
                                            >
                                                {t(
                                                    `display.message_state_${message.state}`,
                                                )}
                                            </Badge>
                                            {(message.starts_at ||
                                                message.ends_at) && (
                                                <span
                                                    dir="ltr"
                                                    className="tabular-nums"
                                                >
                                                    {message.starts_at?.replace(
                                                        'T',
                                                        ' ',
                                                    ) ?? '…'}{' '}
                                                    →{' '}
                                                    {message.ends_at?.replace(
                                                        'T',
                                                        ' ',
                                                    ) ?? '…'}
                                                </span>
                                            )}
                                        </div>
                                    </div>
                                    <div className="flex shrink-0 items-center gap-1">
                                        <Button
                                            type="button"
                                            variant="ghost"
                                            size="icon"
                                            disabled={index === 0}
                                            onClick={() => move(index, -1)}
                                            aria-label={t('display.move_up')}
                                            title={t('display.move_up')}
                                        >
                                            <ArrowUp className="size-4" />
                                        </Button>
                                        <Button
                                            type="button"
                                            variant="ghost"
                                            size="icon"
                                            disabled={
                                                index === messages.length - 1
                                            }
                                            onClick={() => move(index, 1)}
                                            aria-label={t('display.move_down')}
                                            title={t('display.move_down')}
                                        >
                                            <ArrowDown className="size-4" />
                                        </Button>
                                        <Button
                                            type="button"
                                            variant="ghost"
                                            size="icon"
                                            onClick={() => toggle(message)}
                                            aria-label={
                                                message.active
                                                    ? t('display.pause')
                                                    : t('display.resume')
                                            }
                                            title={
                                                message.active
                                                    ? t('display.pause')
                                                    : t('display.resume')
                                            }
                                        >
                                            {message.active ? (
                                                <Pause className="size-4" />
                                            ) : (
                                                <Play className="size-4" />
                                            )}
                                        </Button>
                                        <Button
                                            type="button"
                                            variant="ghost"
                                            size="icon"
                                            onClick={() =>
                                                setEditing(message.id)
                                            }
                                            aria-label={t('display.edit')}
                                            title={t('display.edit')}
                                        >
                                            <Pencil className="size-4" />
                                        </Button>
                                        {confirming === message.id ? (
                                            <Button
                                                type="button"
                                                variant="destructive"
                                                size="sm"
                                                onClick={() =>
                                                    router.delete(
                                                        `${base}/${message.id}`,
                                                        {
                                                            ...options,
                                                            onFinish: () =>
                                                                setConfirming(
                                                                    null,
                                                                ),
                                                        },
                                                    )
                                                }
                                            >
                                                {t('display.confirm_delete')}
                                            </Button>
                                        ) : (
                                            <Button
                                                type="button"
                                                variant="ghost"
                                                size="icon"
                                                onClick={() =>
                                                    setConfirming(message.id)
                                                }
                                                aria-label={t('display.delete')}
                                                title={t('display.delete')}
                                                className="text-destructive hover:text-destructive"
                                            >
                                                <Trash2 className="size-4" />
                                            </Button>
                                        )}
                                    </div>
                                </div>
                            )}
                        </li>
                    ))}
                </ol>
            )}
        </Section>
    );
}
