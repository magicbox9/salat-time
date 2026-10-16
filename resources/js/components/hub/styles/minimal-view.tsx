import { useT } from '@/lib/i18n';
import { cn } from '@/lib/utils';
import { Clock, Countdown, RowExtras, usePrayerName } from '../bits';
import type { DayView, HubPrefs } from '../types';

type Props = { view: DayView; prefs: HubPrefs };

/** "Minimal": a large, quiet list — names and times, nothing else. */
export function MinimalView({ view, prefs }: Props) {
    const t = useT();
    const name = usePrayerName();

    return (
        <ul className="divide-y divide-border/70 border-y border-border/70">
            {view.rows.map((row) => {
                const next = row.state === 'next';

                return (
                    <li
                        key={row.prayer}
                        aria-current={next ? 'time' : undefined}
                        className={cn(
                            'flex items-center justify-between gap-4',
                            prefs.compact ? 'py-2.5' : 'py-4 sm:py-5',
                            row.state === 'passed' && 'text-muted-foreground',
                        )}
                    >
                        <span className="min-w-0">
                            <span
                                className={cn(
                                    'flex items-center gap-3 font-light',
                                    prefs.compact
                                        ? 'text-lg'
                                        : 'text-xl sm:text-2xl',
                                    next && 'font-normal text-primary',
                                    row.prayer === 'shuruq' &&
                                        'text-muted-foreground',
                                )}
                            >
                                <span
                                    aria-hidden
                                    className={cn(
                                        'size-2 shrink-0 rounded-full',
                                        next
                                            ? 'bg-gold motion-safe:animate-pulse'
                                            : row.state === 'current'
                                              ? 'bg-primary'
                                              : 'bg-transparent',
                                    )}
                                />
                                {name(row.prayer)}
                            </span>
                            {next && view.untilNext !== null && (
                                <span className="mt-1 block ps-5 text-sm text-muted-foreground">
                                    {t('hub.in')}{' '}
                                    <Countdown
                                        minutes={view.untilNext}
                                        prefs={prefs}
                                        className="text-foreground"
                                    />
                                </span>
                            )}
                        </span>
                        <span className="flex flex-col items-end text-end">
                            <Clock
                                value={row.time}
                                prefs={prefs}
                                className={cn(
                                    'font-extralight tracking-tight',
                                    prefs.compact
                                        ? 'text-3xl'
                                        : 'text-4xl sm:text-5xl',
                                    next && 'font-light text-primary',
                                )}
                            />
                            <RowExtras
                                row={row}
                                prefs={prefs}
                                className="justify-end text-xs text-muted-foreground"
                            />
                        </span>
                    </li>
                );
            })}
        </ul>
    );
}
