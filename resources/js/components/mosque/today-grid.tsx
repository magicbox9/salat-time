import { Sunrise } from 'lucide-react';
import { useNow } from '@/hooks/use-now';
import { useT } from '@/lib/i18n';
import { currentPrayer, nextPrayer } from '@/lib/prayer-time';
import { cn } from '@/lib/utils';
import type { DayTimes } from '@/types/mosque';
import { PRAYERS } from '@/types/mosque';

type Props = {
    today: DayTimes;
    tomorrow: DayTimes | null;
    timezone: string;
    jumua: string[];
    jumuaAsDhuhr: boolean;
};

/** Today's six published times as tiles (adhan and iqama), next prayer in gold. */
export function TodayGrid({
    today,
    tomorrow,
    timezone,
    jumua,
    jumuaAsDhuhr,
}: Props) {
    const t = useT();
    const now = useNow(15_000);
    const next = nextPrayer(today, tomorrow, timezone, now);
    const current = currentPrayer(today, timezone, now);
    const upcoming = next && !next.tomorrow ? next.prayer : null;
    const passedUntil = upcoming ? PRAYERS.indexOf(upcoming) : PRAYERS.length;
    const jumuaTimes = jumuaAsDhuhr ? [today.times.dhuhr] : jumua;

    return (
        <div className="space-y-3">
            <ul className="grid grid-cols-2 gap-2.5 sm:grid-cols-3">
                {PRAYERS.map((prayer, index) => {
                    const iqama =
                        prayer === 'shuruq' ? null : today.iqama[prayer];
                    const isNext = prayer === upcoming;
                    const isNow = prayer === current;

                    return (
                        <li
                            key={prayer}
                            className={cn(
                                'relative rounded-xl border bg-card px-4 py-3 transition-colors',
                                index < passedUntil && !isNow && 'opacity-60',
                                isNow && 'border-primary/40 bg-primary/5',
                                isNext &&
                                    'border-gold/70 bg-gold/10 shadow-sm ring-1 ring-gold/40',
                            )}
                            aria-current={isNext ? 'time' : undefined}
                        >
                            <div className="flex items-center justify-between gap-2">
                                <span className="text-sm font-medium text-muted-foreground">
                                    {t(`site.prayer_${prayer}`)}
                                </span>
                                {prayer === 'shuruq' && (
                                    <Sunrise className="size-4 text-muted-foreground" />
                                )}
                                {isNext && (
                                    <span className="rounded-full bg-gold/25 px-2 py-0.5 text-[10px] font-semibold tracking-wide text-foreground uppercase">
                                        {t('mosque.next')}
                                    </span>
                                )}
                                {isNow && !isNext && (
                                    <span className="rounded-full bg-primary/15 px-2 py-0.5 text-[10px] font-semibold tracking-wide text-primary uppercase">
                                        {t('mosque.now')}
                                    </span>
                                )}
                            </div>
                            <p
                                className="mt-1 text-2xl font-semibold tabular-nums"
                                dir="ltr"
                            >
                                {today.times[prayer]}
                            </p>
                            <p className="mt-0.5 h-4 text-xs text-muted-foreground">
                                {iqama && (
                                    <>
                                        {t('site.iqama')}{' '}
                                        <span
                                            dir="ltr"
                                            className="tabular-nums"
                                        >
                                            {iqama}
                                        </span>
                                    </>
                                )}
                            </p>
                        </li>
                    );
                })}
            </ul>
            {jumuaTimes.length > 0 && (
                <div className="flex flex-wrap items-center justify-between gap-2 rounded-xl border border-gold/40 bg-gold/5 px-4 py-3">
                    <span className="text-sm font-medium">
                        {t('site.prayer_jumua')}
                    </span>
                    <span className="flex flex-wrap gap-2" dir="ltr">
                        {jumuaTimes.map((time, index) => (
                            <span
                                key={index}
                                className="rounded-lg bg-background px-2.5 py-1 text-sm font-semibold tabular-nums shadow-xs"
                            >
                                {time}
                            </span>
                        ))}
                    </span>
                </div>
            )}
        </div>
    );
}
