import type { ReactNode } from 'react';
import { useFormatDate } from '@/components/claims/use-format-date';
import { MarkdownContent } from '@/components/markdown-content';
import type { CampaignUpdateData } from './types';

/** News from the mosque about the campaign, newest first, on a quiet vertical line. */
export function UpdatesTimeline({
    updates,
    action,
}: {
    updates: CampaignUpdateData[];
    /** e.g. a delete button for managers. */
    action?: (update: CampaignUpdateData) => ReactNode;
}) {
    const formatDate = useFormatDate();

    if (updates.length === 0) {
        return null;
    }

    return (
        <ol className="relative space-y-6 border-s-2 border-gold/40 ps-6">
            {updates.map((update) => (
                <li key={update.id} className="relative">
                    <span
                        aria-hidden
                        className="absolute -start-[calc(1.5rem+7px)] top-1.5 size-3 rounded-full border-2 border-background bg-gold ring-2 ring-gold/30"
                    />
                    <div className="flex items-start justify-between gap-3">
                        <div className="min-w-0">
                            <p className="text-xs font-medium tracking-wide text-muted-foreground uppercase">
                                <time dateTime={update.created_at ?? undefined}>
                                    {formatDate(update.created_at)}
                                </time>
                            </p>
                            <h3 className="mt-0.5 font-semibold">
                                {update.title}
                            </h3>
                        </div>
                        {action?.(update)}
                    </div>
                    <MarkdownContent
                        html={update.body_html}
                        className="mt-2 text-sm text-foreground/90"
                    />
                </li>
            ))}
        </ol>
    );
}
