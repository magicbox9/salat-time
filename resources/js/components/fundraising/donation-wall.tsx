import { HeartHandshake } from 'lucide-react';
import { useT } from '@/lib/i18n';
import { cn } from '@/lib/utils';
import { useMoney, useTimeAgo } from './format';
import type { WallEntry } from './types';

/** Initials for the round avatar ("Yasmine B." → "YB"); a heart for anonymous gifts. */
function initials(name: string): string {
    return name
        .split(/\s+/)
        .filter(Boolean)
        .slice(0, 2)
        .map((part) => part[0]?.toUpperCase() ?? '')
        .join('');
}

/** The latest completed donations: name (unless anonymous), amount, a word of support. */
export function DonationWall({ entries }: { entries: WallEntry[] }) {
    const t = useT();
    const money = useMoney();
    const ago = useTimeAgo();

    return (
        <section aria-labelledby="donation-wall" className="space-y-4">
            <h2
                id="donation-wall"
                className="text-xl font-semibold tracking-tight"
            >
                {t('fundraising.wall_title')}
            </h2>
            {entries.length === 0 ? (
                <p className="rounded-2xl border border-dashed px-5 py-8 text-center text-sm text-muted-foreground">
                    {t('fundraising.wall_empty')}
                </p>
            ) : (
                <ul
                    className="divide-y rounded-2xl border bg-card"
                    aria-live="polite"
                >
                    {entries.map((entry, index) => (
                        <li
                            key={entry.id}
                            className={cn(
                                'flex animate-in gap-3 p-4 duration-500 fade-in slide-in-from-top-1 motion-reduce:animate-none',
                                index === 0 && 'rounded-t-2xl',
                            )}
                        >
                            <span
                                aria-hidden
                                className={cn(
                                    'flex size-10 shrink-0 items-center justify-center rounded-full text-sm font-semibold',
                                    entry.name
                                        ? 'bg-primary/10 text-primary'
                                        : 'bg-gold/20 text-amber-800 dark:text-gold',
                                )}
                            >
                                {entry.name ? (
                                    initials(entry.name)
                                ) : (
                                    <HeartHandshake className="size-4" />
                                )}
                            </span>
                            <div className="min-w-0 flex-1">
                                <p className="flex flex-wrap items-baseline gap-x-2">
                                    <span className="truncate font-medium">
                                        {entry.name ??
                                            t('fundraising.anonymous_donor')}
                                    </span>
                                    <span className="text-xs text-muted-foreground">
                                        {ago(entry.at)}
                                    </span>
                                </p>
                                <p
                                    className="text-sm font-semibold text-primary"
                                    dir="ltr"
                                >
                                    <span className="inline-block">
                                        {money(entry.amount, entry.currency)}
                                    </span>
                                </p>
                                {entry.message && (
                                    <p className="mt-1 text-sm break-words whitespace-pre-line text-muted-foreground">
                                        {entry.message}
                                    </p>
                                )}
                            </div>
                        </li>
                    ))}
                </ul>
            )}
        </section>
    );
}
