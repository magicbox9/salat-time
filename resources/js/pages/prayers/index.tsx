import { Head, router } from '@inertiajs/react';
import { useEffect, useRef, useState } from 'react';
import { BadgeList } from '@/components/prayers/badge-list';
import { CheckInDialog } from '@/components/prayers/check-in-dialog';
import { HasanatRules } from '@/components/prayers/hasanat-rules';
import { MonthHeatmap } from '@/components/prayers/month-heatmap';
import { MosqueBanner } from '@/components/prayers/mosque-banner';
import { StatTiles } from '@/components/prayers/stat-tiles';
import { TodayPrayers } from '@/components/prayers/today-prayers';
import { dateInZone, deviceTimezone } from '@/components/prayers/tracker-utils';
import type {
    CheckInTarget,
    TrackerPageProps,
} from '@/components/prayers/types';
import { WeekGrid } from '@/components/prayers/week-grid';
import { useNow } from '@/hooks/use-now';
import { useT } from '@/lib/i18n';

/** My prayers: today's check-in, hasanat, streaks, the week and the month. */
export default function PrayersIndex(props: TrackerPageProps) {
    const t = useT();
    const { clock, mosque, times, today, week, stats, badges, rules, month } =
        props;
    const [target, setTarget] = useState<CheckInTarget | null>(null);
    const empty =
        stats.prayers_prayed === 0 &&
        week.every((day) => Object.values(day.prayers).every((log) => !log));

    // Without an own mosque, "today" follows the device's time zone.
    useEffect(() => {
        const tz = deviceTimezone();

        const asked = new URLSearchParams(window.location.search).has('tz');

        // Ask once: the server falls back to its default when it does not know the zone.
        if (
            clock.source !== 'mosque' &&
            tz &&
            tz !== clock.timezone &&
            !asked
        ) {
            router.get(
                '/prayers',
                { tz },
                { preserveState: true, preserveScroll: true, replace: true },
            );
        }
    }, [clock.source, clock.timezone]);

    // A page left open past midnight would check prayers in on yesterday's
    // date: reload when the day changes in the tracker's time zone.
    const now = useNow(60_000);
    const currentDay = dateInZone(clock.timezone, now);
    const shown = useRef({ timezone: clock.timezone, day: currentDay });

    useEffect(() => {
        const previous = shown.current;
        shown.current = { timezone: clock.timezone, day: currentDay };

        // A new time zone (device zone just applied) is not a new day.
        if (
            previous.timezone === clock.timezone &&
            previous.day !== currentDay
        ) {
            router.reload();
        }
    }, [clock.timezone, currentDay]);

    return (
        <>
            <Head title={t('prayers.page_title')} />

            <div className="space-y-6">
                <header className="space-y-3">
                    <div>
                        <h1 className="text-2xl font-semibold tracking-tight sm:text-3xl">
                            {t('prayers.page_title')}
                        </h1>
                        <p className="mt-1 text-muted-foreground">
                            {t('prayers.page_intro')}
                        </p>
                    </div>
                    <MosqueBanner
                        mosque={mosque}
                        times={times?.today ?? null}
                        timezone={clock.timezone}
                    />
                </header>

                <StatTiles
                    todayHasanat={today.hasanat}
                    totalHasanat={stats.total_hasanat}
                    currentStreak={stats.streak.current}
                    bestStreak={stats.streak.best}
                />

                {empty && (
                    <p className="rounded-xl border border-primary/20 bg-primary/5 p-4 text-sm leading-relaxed">
                        {t('prayers.empty_state')}
                    </p>
                )}

                <div className="grid gap-6 lg:grid-cols-3">
                    <div className="space-y-6 lg:col-span-2">
                        <TodayPrayers
                            day={today}
                            times={times?.today ?? null}
                            timezone={clock.timezone}
                            onOpen={setTarget}
                        />
                        <WeekGrid
                            week={week}
                            today={clock.today}
                            editableFrom={clock.editable_from}
                            onOpen={setTarget}
                        />
                    </div>

                    <aside className="space-y-6">
                        <MonthHeatmap month={month} today={clock.today} />
                        <BadgeList badges={badges} />
                        <HasanatRules rules={rules} />
                    </aside>
                </div>
            </div>

            <CheckInDialog
                target={target}
                today={clock.today}
                mosque={mosque}
                onClose={() => setTarget(null)}
            />
        </>
    );
}
