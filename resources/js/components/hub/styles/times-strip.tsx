import { cn } from '@/lib/utils';
import { Clock, RowExtras, usePrayerName } from '../bits';
import type { DayView, HubPrefs } from '../types';

/** The six times in a compact row under the sky views (Sky arc, Dial). */
export function TimesStrip({
    view,
    prefs,
}: {
    view: DayView;
    prefs: HubPrefs;
}) {
    const name = usePrayerName();

    return (
        <ul className="grid grid-cols-3 gap-1.5 sm:grid-cols-6">
            {view.rows.map((row) => (
                <li
                    key={row.prayer}
                    aria-current={row.state === 'next' ? 'time' : undefined}
                    className={cn(
                        'rounded-xl px-2.5 py-2 text-center',
                        row.state === 'next'
                            ? 'bg-primary text-primary-foreground ring-2 ring-gold/60'
                            : row.state === 'current'
                              ? 'bg-gold/12 ring-1 ring-gold/40'
                              : 'bg-muted/60',
                        row.state === 'passed' && 'text-muted-foreground',
                    )}
                >
                    <span className="block truncate text-xs font-medium">
                        {name(row.prayer)}
                    </span>
                    <Clock
                        value={row.time}
                        prefs={prefs}
                        className={cn(
                            'block font-light',
                            prefs.compact ? 'text-base' : 'text-lg sm:text-xl',
                        )}
                    />
                    <RowExtras
                        row={row}
                        prefs={prefs}
                        className={cn(
                            'justify-center text-[0.7rem] leading-tight',
                            row.state === 'next'
                                ? 'text-primary-foreground/80'
                                : 'text-muted-foreground',
                        )}
                    />
                </li>
            ))}
        </ul>
    );
}
