import { CalendarClock, PencilLine, Send } from 'lucide-react';
import InputError from '@/components/input-error';
import { Input } from '@/components/ui/input';
import { useT } from '@/lib/i18n';
import { cn } from '@/lib/utils';
import type { PublishStatus } from './status-badge';

type Props = {
    status: PublishStatus;
    publishAt: string;
    timezone: string;
    /** The post is public already: "Publish now" keeps its date. */
    wasPublished: boolean;
    onStatus: (status: PublishStatus) => void;
    onPublishAt: (value: string) => void;
    error?: string;
};

/** When the post goes public: now, at a set time, or not yet (draft). */
export function PublishPanel({
    status,
    publishAt,
    timezone,
    wasPublished,
    onStatus,
    onPublishAt,
    error,
}: Props) {
    const t = useT();
    const options: {
        value: PublishStatus;
        icon: typeof Send;
        label: string;
        hint: string;
    }[] = [
        {
            value: 'published',
            icon: Send,
            label: wasPublished
                ? t('manage.status_keep_published')
                : t('manage.status_publish_now'),
            hint: wasPublished
                ? t('manage.status_keep_published_hint')
                : t('manage.status_publish_now_hint'),
        },
        {
            value: 'scheduled',
            icon: CalendarClock,
            label: t('manage.status_schedule'),
            hint: t('manage.status_schedule_hint'),
        },
        {
            value: 'draft',
            icon: PencilLine,
            label: t('manage.status_draft'),
            hint: t('manage.status_draft_hint'),
        },
    ];

    return (
        <div className="grid gap-3">
            <div
                role="radiogroup"
                aria-label={t('manage.publication')}
                className="grid gap-2 sm:grid-cols-3"
            >
                {options.map((option) => {
                    const active = status === option.value;

                    return (
                        <button
                            key={option.value}
                            type="button"
                            role="radio"
                            aria-checked={active}
                            onClick={() => onStatus(option.value)}
                            className={cn(
                                'flex flex-col items-start gap-1 rounded-xl border px-3 py-3 text-start transition-colors outline-none focus-visible:ring-2 focus-visible:ring-ring/60',
                                active
                                    ? 'border-primary bg-primary/5 ring-1 ring-primary/40'
                                    : 'hover:bg-accent/60',
                            )}
                        >
                            <option.icon
                                className={cn(
                                    'size-5',
                                    active
                                        ? 'text-primary'
                                        : 'text-muted-foreground',
                                )}
                                aria-hidden
                            />
                            <span className="text-sm font-medium">
                                {option.label}
                            </span>
                            <span className="text-xs text-muted-foreground">
                                {option.hint}
                            </span>
                        </button>
                    );
                })}
            </div>
            {status === 'scheduled' && (
                <div className="grid gap-1.5 sm:w-72">
                    <label htmlFor="publish_at" className="text-sm font-medium">
                        {t('manage.publish_at')}
                    </label>
                    <Input
                        id="publish_at"
                        type="datetime-local"
                        dir="ltr"
                        required
                        value={publishAt}
                        onChange={(event) => onPublishAt(event.target.value)}
                        aria-invalid={error ? true : undefined}
                    />
                    <p className="text-xs text-muted-foreground">
                        {t('manage.event_hint', { timezone })}
                    </p>
                </div>
            )}
            <InputError message={error} />
        </div>
    );
}
