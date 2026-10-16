import { Moon, Sun } from 'lucide-react';
import type { CSSProperties } from 'react';
import { useT } from '@/lib/i18n';
import { cn } from '@/lib/utils';
import {
    Clock,
    Countdown,
    PRAYER_ICON,
    RowExtras,
    usePrayerName,
} from '../bits';
import { isDaytime, timelinePosition } from '../day';
import type { DayView, HubPrefs } from '../types';

type Props = { view: DayView; prefs: HubPrefs };

/**
 * "Timeline": the day as a vertical path. The rail fills as the day goes
 * and the sun (or the moon at night) sits where "now" is between prayers.
 */
export function TimelineView({ view, prefs }: Props) {
    const t = useT();
    const name = usePrayerName();
    const position = timelinePosition(view);
    // Rail length already lived, from the first row's centre to the last one's.
    const lived = Math.max(0, Math.min(position, view.rows.length - 0.5) - 0.5);
    const day = isDaytime(view);
    const style = {
        '--row': prefs.compact ? '3.75rem' : '4.75rem',
        '--rail': '6.5rem',
    } as CSSProperties;

    return (
        <div className="rounded-2xl border bg-card p-3 sm:p-5">
            <ol className="relative" style={style}>
                {/* The rail, then the part of the day already lived. */}
                <span
                    aria-hidden
                    className="absolute start-[var(--rail)] top-[calc(var(--row)/2)] bottom-[calc(var(--row)/2)] w-0.5 -translate-x-1/2 rounded-full bg-border rtl:translate-x-1/2"
                />
                <span
                    aria-hidden
                    className="absolute start-[var(--rail)] top-[calc(var(--row)/2)] w-0.5 -translate-x-1/2 rounded-full bg-gradient-to-b from-primary/40 via-primary to-gold rtl:translate-x-1/2"
                    style={{ height: `calc(${lived} * var(--row))` }}
                />
                <span
                    aria-hidden
                    className={cn(
                        'absolute start-[var(--rail)] z-10 flex size-7 -translate-x-1/2 -translate-y-1/2 items-center justify-center rounded-full rtl:translate-x-1/2',
                        day
                            ? 'bg-gold text-[oklch(0.35_0.08_70)] shadow-[0_0_18px_4px_color-mix(in_oklab,var(--gold)_55%,transparent)]'
                            : 'bg-[oklch(0.28_0.05_260)] text-[oklch(0.93_0.03_95)] shadow-[0_0_14px_3px_oklch(0.7_0.05_260/0.45)]',
                    )}
                    style={{ top: `calc(${position} * var(--row))` }}
                >
                    {day ? (
                        <Sun className="size-4 motion-safe:animate-[spin_24s_linear_infinite]" />
                    ) : (
                        <Moon className="size-3.5" />
                    )}
                </span>

                {view.rows.map((row) => {
                    const Icon = PRAYER_ICON[row.prayer];
                    const next = row.state === 'next';
                    const passed = row.state === 'passed';

                    return (
                        <li
                            key={row.prayer}
                            aria-current={next ? 'time' : undefined}
                            className="relative grid h-[var(--row)] grid-cols-[calc(var(--rail)_-_1.25rem)_2.5rem_1fr] items-center"
                        >
                            <Clock
                                value={row.time}
                                prefs={prefs}
                                className={cn(
                                    'justify-self-end font-light tracking-tight',
                                    prefs.compact
                                        ? 'text-xl'
                                        : 'text-2xl sm:text-3xl',
                                    next && 'font-normal text-primary',
                                    passed && 'text-muted-foreground',
                                )}
                            />
                            <span className="flex justify-center">
                                <span
                                    aria-hidden
                                    className={cn(
                                        'size-3 rounded-full border-2',
                                        passed || row.state === 'current'
                                            ? 'border-primary bg-primary'
                                            : 'border-border bg-background',
                                        next &&
                                            'size-3.5 border-gold bg-background ring-4 ring-gold/20',
                                    )}
                                />
                            </span>
                            <span className="flex min-w-0 items-center justify-between gap-3">
                                <span className="min-w-0">
                                    <span
                                        className={cn(
                                            'flex items-center gap-2 font-medium',
                                            prefs.compact
                                                ? 'text-sm'
                                                : 'text-base',
                                            passed && 'text-muted-foreground',
                                            row.prayer === 'shuruq' &&
                                                'font-normal text-muted-foreground',
                                        )}
                                    >
                                        <Icon
                                            aria-hidden
                                            className={cn(
                                                'size-4 shrink-0',
                                                next || row.state === 'current'
                                                    ? 'text-gold'
                                                    : 'text-muted-foreground',
                                            )}
                                        />
                                        {name(row.prayer)}
                                    </span>
                                    <RowExtras
                                        row={row}
                                        prefs={prefs}
                                        className="mt-0.5 ps-6 text-xs text-muted-foreground"
                                    />
                                </span>
                                {next && view.untilNext !== null && (
                                    <span className="shrink-0 rounded-full bg-primary/10 px-2.5 py-1 text-xs text-primary">
                                        {t('hub.in')}{' '}
                                        <Countdown
                                            minutes={view.untilNext}
                                            prefs={prefs}
                                        />
                                    </span>
                                )}
                                {row.state === 'current' && (
                                    <span className="shrink-0 rounded-full bg-gold/15 px-2.5 py-1 text-xs font-medium ring-1 ring-gold/40">
                                        {t('hub.now')}
                                    </span>
                                )}
                            </span>
                        </li>
                    );
                })}
            </ol>
        </div>
    );
}
