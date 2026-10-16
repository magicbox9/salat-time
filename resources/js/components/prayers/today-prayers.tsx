import { usePage } from '@inertiajs/react';
import { useNow } from '@/hooks/use-now';
import { intlLocale, useT } from '@/lib/i18n';
import type { DayTimes } from '@/types/mosque';
import { formatDay, prayerWindow, suggestStatus } from './tracker-utils';
import { PrayerRow } from './prayer-row';
import type { CheckInTarget, TrackerDay } from './types';
import { TRACKED_PRAYERS } from './types';

type Props = {
    day: TrackerDay;
    times: DayTimes | null;
    timezone: string;
    onOpen: (target: CheckInTarget) => void;
};

/** Today's five prayers with quick check-in. */
export function TodayPrayers({ day, times, timezone, onOpen }: Props) {
    const t = useT();
    const { locale } = usePage().props;
    const now = useNow(30_000);
    const done = TRACKED_PRAYERS.filter(
        (p) => day.prayers[p] && day.prayers[p]!.status !== 'missed',
    ).length;

    return (
        <section
            className="overflow-hidden rounded-xl border bg-card shadow-sm"
            aria-labelledby="today-heading"
        >
            <header className="flex flex-wrap items-end justify-between gap-2 border-b px-4 py-4 sm:px-5">
                <div>
                    <h2 id="today-heading" className="text-lg font-semibold">
                        {t('prayers.today_title')}
                    </h2>
                    <p className="text-sm text-muted-foreground">
                        {formatDay(day.date, intlLocale(locale), {
                            weekday: 'long',
                            day: 'numeric',
                            month: 'long',
                        })}
                    </p>
                </div>
                <p className="text-sm text-muted-foreground">
                    {t('prayers.today_progress', {
                        done,
                        total: TRACKED_PRAYERS.length,
                    })}
                </p>
            </header>
            <ul className="divide-y">
                {TRACKED_PRAYERS.map((prayer) => {
                    const window = prayerWindow(prayer, times, timezone, now);
                    const log = day.prayers[prayer];

                    return (
                        <PrayerRow
                            key={prayer}
                            prayer={prayer}
                            date={day.date}
                            log={log}
                            times={times}
                            window={window}
                            onOpen={() =>
                                onOpen({
                                    date: day.date,
                                    prayer,
                                    log,
                                    suggested: suggestStatus(window),
                                })
                            }
                        />
                    );
                })}
            </ul>
        </section>
    );
}
