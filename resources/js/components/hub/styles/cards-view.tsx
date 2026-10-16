import { useT } from '@/lib/i18n';
import { cn } from '@/lib/utils';
import {
    Clock,
    Countdown,
    PRAYER_ICON,
    RowExtras,
    usePrayerName,
} from '../bits';
import type { DayView, HubPrefs } from '../types';

type Props = { view: DayView; prefs: HubPrefs };

/** "Cards": an elegant grid, the next prayer lit in deep green and gold. */
export function CardsView({ view, prefs }: Props) {
    const t = useT();
    const name = usePrayerName();

    return (
        <ul
            className={cn(
                'grid grid-cols-2 sm:grid-cols-3 xl:grid-cols-6',
                prefs.compact ? 'gap-2' : 'gap-3',
            )}
        >
            {view.rows.map((row) => {
                const Icon = PRAYER_ICON[row.prayer];
                const next = row.state === 'next';
                const sunrise = row.prayer === 'shuruq';

                return (
                    <li
                        key={row.prayer}
                        aria-current={next ? 'time' : undefined}
                        className={cn(
                            'relative flex flex-col overflow-hidden rounded-2xl border transition-colors',
                            prefs.compact ? 'gap-1 p-3' : 'gap-2 p-4 sm:p-5',
                            next
                                ? 'border-transparent bg-gradient-to-br from-[oklch(0.44_0.09_168)] via-[oklch(0.38_0.075_176)] to-[oklch(0.3_0.055_195)] text-white shadow-lg ring-2 ring-gold/70'
                                : 'bg-card',
                            row.state === 'current' &&
                                'border-gold/50 bg-[color-mix(in_oklab,var(--gold)_7%,var(--card))]',
                            row.state === 'passed' && 'text-muted-foreground',
                            sunrise && !next && 'border-dashed bg-transparent',
                        )}
                    >
                        {next && (
                            <span
                                aria-hidden
                                className="pointer-events-none absolute -end-10 -top-12 size-32 rounded-full bg-[radial-gradient(circle,oklch(0.85_0.12_85/0.35),transparent_65%)]"
                            />
                        )}
                        <span className="relative flex items-center justify-between gap-2">
                            <span
                                className={cn(
                                    'text-sm font-medium',
                                    next
                                        ? 'text-white/90'
                                        : sunrise && 'text-muted-foreground',
                                )}
                            >
                                {name(row.prayer)}
                            </span>
                            <Icon
                                aria-hidden
                                className={cn(
                                    'size-4 shrink-0',
                                    next
                                        ? 'text-gold'
                                        : row.state === 'current'
                                          ? 'text-gold'
                                          : 'text-muted-foreground',
                                )}
                            />
                        </span>
                        <Clock
                            value={row.time}
                            prefs={prefs}
                            className={cn(
                                // self-start: a left-to-right time still sits at the card's start in Arabic.
                                'relative self-start font-light tracking-tight',
                                prefs.compact
                                    ? 'text-2xl'
                                    : 'text-3xl sm:text-4xl',
                                row.state === 'passed' && 'opacity-70',
                            )}
                        />
                        <RowExtras
                            row={row}
                            prefs={prefs}
                            className={cn(
                                'relative text-xs',
                                next
                                    ? 'text-white/80'
                                    : 'text-muted-foreground',
                            )}
                        />
                        {next && view.untilNext !== null && (
                            <span className="relative mt-auto inline-flex w-fit items-center gap-1.5 rounded-full bg-white/12 px-2.5 py-1 text-xs ring-1 ring-white/20">
                                {t('hub.in')}
                                <Countdown
                                    minutes={view.untilNext}
                                    prefs={prefs}
                                />
                            </span>
                        )}
                        {row.state === 'current' && (
                            <span className="mt-auto inline-flex w-fit items-center gap-1.5 rounded-full bg-gold/15 px-2.5 py-1 text-xs font-medium text-foreground ring-1 ring-gold/40">
                                <span className="size-1.5 rounded-full bg-gold motion-safe:animate-pulse" />
                                {t('hub.now')}
                            </span>
                        )}
                    </li>
                );
            })}
        </ul>
    );
}
