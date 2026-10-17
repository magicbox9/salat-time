import {
    CalculatedTag,
    isCalculated,
} from '@/components/prayer/calculated-notice';
import { useNow } from '@/hooks/use-now';
import { useT } from '@/lib/i18n';
import { currentPrayer, formatCountdown, nextPrayer } from '@/lib/prayer-time';
import { cn } from '@/lib/utils';
import type { DayTimes, PrayerName } from '@/types/mosque';
import { PRAYERS } from '@/types/mosque';

type Props = {
    today: DayTimes | null;
    tomorrow: DayTimes | null;
    timezone: string;
    /** Show the iqama column. */
    showIqama?: boolean;
    compact?: boolean;
    className?: string;
};

/**
 * Today's times with the next prayer highlighted and a live countdown,
 * marked when they are calculated (the mosque publishes none). Shared by
 * the map popup and the dashboard.
 */
export function TodayTimes({
    today,
    tomorrow,
    timezone,
    showIqama = true,
    compact = false,
    className,
}: Props) {
    const t = useT();
    const now = useNow();

    if (!today) {
        return (
            <p className={cn('text-sm text-muted-foreground', className)}>
                {t('site.no_times')}
            </p>
        );
    }

    const next = nextPrayer(today, tomorrow, timezone, now);
    const current = currentPrayer(today, timezone, now);
    const highlight: PrayerName | null =
        next && !next.tomorrow ? next.prayer : null;

    return (
        <div className={cn('space-y-3', className)}>
            {next && (
                <div className="flex items-baseline justify-between gap-3 rounded-lg bg-primary/10 px-3 py-2">
                    <span className="text-sm font-medium text-primary">
                        {t('site.next_prayer')}:{' '}
                        {t(`site.prayer_${next.prayer}`)}{' '}
                        <span dir="ltr">{next.time}</span>
                    </span>
                    <span
                        className="font-mono text-sm text-primary tabular-nums"
                        dir="ltr"
                    >
                        {formatCountdown(next.inMinutes)}
                    </span>
                </div>
            )}
            <ul
                className={cn(
                    'divide-y divide-border',
                    compact ? 'text-sm' : '',
                )}
            >
                {PRAYERS.map((prayer) => {
                    const iqama =
                        prayer === 'shuruq' ? null : today.iqama[prayer];

                    return (
                        <li
                            key={prayer}
                            className={cn(
                                'flex items-center justify-between gap-3 py-1.5',
                                prayer === highlight &&
                                    'font-semibold text-primary',
                                prayer === current && 'text-foreground',
                                prayer === 'shuruq' && 'text-muted-foreground',
                            )}
                        >
                            <span>{t(`site.prayer_${prayer}`)}</span>
                            <span
                                className="flex items-baseline gap-3 tabular-nums"
                                dir="ltr"
                            >
                                <span>{today.times[prayer]}</span>
                                {showIqama && (
                                    <span className="w-12 text-end text-xs text-muted-foreground">
                                        {iqama ?? ''}
                                    </span>
                                )}
                            </span>
                        </li>
                    );
                })}
                {today.jumua && (
                    <li className="flex items-center justify-between gap-3 py-1.5">
                        <span>{t('site.prayer_jumua')}</span>
                        <span className="tabular-nums" dir="ltr">
                            {today.jumua}
                        </span>
                    </li>
                )}
            </ul>
            {isCalculated(today) && (
                <p className="flex items-start gap-2 text-xs text-muted-foreground">
                    <CalculatedTag />
                    <span>{t('site.calculated_hint')}</span>
                </p>
            )}
        </div>
    );
}
