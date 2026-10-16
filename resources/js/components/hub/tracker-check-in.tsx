import { Link, router } from '@inertiajs/react';
import {
    ArrowUpRight,
    Check,
    CircleCheck,
    HandHeart,
    Landmark,
} from 'lucide-react';
import { useState } from 'react';
import { toast } from 'sonner';
import { Button } from '@/components/ui/button';
import { useT } from '@/lib/i18n';
import { cn } from '@/lib/utils';
import { usePrayerName } from './bits';
import { deviceTimezone } from './format';
import type { DayView, HubTracker, TrackedPrayer } from './types';

const TRACKED: TrackedPrayer[] = ['fajr', 'dhuhr', 'asr', 'maghrib', 'isha'];

/** The event that ends each prayer's time (as the tracker suggests "on time" or "late"). */
const ENDS_AT: Record<TrackedPrayer, 'shuruq' | TrackedPrayer | null> = {
    fajr: 'shuruq',
    dhuhr: 'asr',
    asr: 'maghrib',
    maghrib: 'isha',
    isha: null,
};

type Props = { tracker: HubTracker; view: DayView | null; mosqueId: number };

/**
 * One-tap check-in for the prayer whose time has come (POST /prayers/logs,
 * module "prayers"), and today's five prayers at a glance.
 */
export function TrackerCheckIn({ tracker, view, mosqueId }: Props) {
    const t = useT();
    const name = usePrayerName();
    const [busy, setBusy] = useState(false);

    // The prayer day on screen: today, or the evening before while its
    // Isha (published after midnight) still holds the night.
    const day =
        view?.today.date === tracker.date
            ? { date: tracker.date, logs: tracker.logs }
            : view?.today.date === tracker.previous.date
              ? tracker.previous
              : null;
    const logs = day?.logs ?? tracker.logs;
    const minutes = (prayer: string) =>
        view?.rows.find((row) => row.prayer === prayer)?.minutes ?? null;
    const reached =
        day && view
            ? ([...TRACKED]
                  .reverse()
                  .find(
                      (prayer) =>
                          (minutes(prayer) ?? Infinity) <= view.nowMinutes,
                  ) ?? null)
            : null;
    // Before Fajr, the last prayer is the night's Isha, on the day before.
    const lastNight = !reached && !!view && day?.date === tracker.date;
    const entry =
        reached && day
            ? { prayer: reached, date: day.date, logs: day.logs }
            : lastNight
              ? {
                    prayer: 'isha' as const,
                    date: tracker.previous.date,
                    logs: tracker.previous.logs,
                }
              : null;
    const target = entry?.prayer ?? null;
    const log = entry ? entry.logs[entry.prayer] : null;
    const end = reached ? ENDS_AT[reached] : null;
    const suggested =
        end && view && (minutes(end) ?? Infinity) <= view.nowMinutes
            ? 'late'
            : 'on_time';
    const prayed = TRACKED.filter((prayer) => {
        const status = logs[prayer]?.status;

        return status !== undefined && status !== 'missed';
    }).length;

    const checkIn = (atMosque: boolean) => {
        if (!entry) {
            return;
        }

        router.post(
            '/prayers/logs',
            {
                prayer_date: entry.date,
                prayer: entry.prayer,
                status: suggested,
                place: atMosque ? 'mosque' : 'home',
                mosque_id: atMosque ? mosqueId : null,
                in_congregation: atMosque,
                tz: deviceTimezone() ?? '',
            },
            {
                preserveScroll: true,
                only: ['tracker'],
                onStart: () => setBusy(true),
                onFinish: () => setBusy(false),
                onError: (errors) => {
                    const first = Object.values(errors)[0];
                    toast.error(
                        typeof first === 'string' && first
                            ? first
                            : t('site.error_generic'),
                    );
                },
            },
        );
    };

    return (
        <section
            aria-labelledby="hub-tracker"
            className="flex flex-col rounded-2xl border bg-card p-5"
        >
            <header className="flex items-center justify-between gap-3">
                <h2
                    id="hub-tracker"
                    className="flex items-center gap-2 font-semibold"
                >
                    <HandHeart className="size-4 text-primary" aria-hidden />
                    {t('hub.tracker_title')}
                </h2>
                <Link
                    href="/prayers"
                    className="flex items-center gap-1 text-sm text-primary hover:underline"
                >
                    {t('hub.tracker_open')}
                    <ArrowUpRight
                        className="size-3.5 rtl:-scale-x-100"
                        aria-hidden
                    />
                </Link>
            </header>

            <ol
                className="mt-4 flex gap-1.5"
                aria-label={t('hub.tracker_today', { count: prayed })}
            >
                {TRACKED.map((prayer) => {
                    const status = logs[prayer]?.status;

                    return (
                        <li key={prayer} className="flex-1 text-center">
                            <span
                                aria-hidden
                                className={cn(
                                    'block h-1.5 rounded-full',
                                    status === undefined
                                        ? 'bg-muted'
                                        : status === 'missed'
                                          ? 'bg-rose-400/60'
                                          : status === 'late'
                                            ? 'bg-amber-500'
                                            : 'bg-primary',
                                    prayer === reached &&
                                        status === undefined &&
                                        'bg-gold/50',
                                )}
                            />
                            <span className="mt-1 block truncate text-[0.7rem] text-muted-foreground">
                                {name(prayer)}
                            </span>
                        </li>
                    );
                })}
            </ol>

            <div className="mt-4 flex-1">
                {target && log ? (
                    <p className="flex items-center gap-2 text-sm">
                        <CircleCheck
                            className="size-4 shrink-0 text-primary"
                            aria-hidden
                        />
                        <span>
                            {t('hub.tracker_logged', { prayer: name(target) })}
                            {log.hasanat > 0 && (
                                <span className="ms-1.5 text-muted-foreground">
                                    ·{' '}
                                    {t('hub.tracker_hasanat', {
                                        count: log.hasanat,
                                    })}
                                </span>
                            )}
                        </span>
                    </p>
                ) : target ? (
                    <>
                        <p className="text-sm">
                            {t(
                                lastNight
                                    ? 'hub.tracker_question_night'
                                    : 'hub.tracker_question',
                                { prayer: name(target) },
                            )}
                        </p>
                        <div className="mt-3 flex flex-wrap gap-2">
                            <Button
                                size="sm"
                                disabled={busy}
                                onClick={() => checkIn(false)}
                            >
                                <Check />
                                {suggested === 'late'
                                    ? t('hub.tracker_prayed_late')
                                    : t('hub.tracker_prayed')}
                            </Button>
                            <Button
                                size="sm"
                                variant="outline"
                                disabled={busy}
                                onClick={() => checkIn(true)}
                            >
                                <Landmark />
                                {t('hub.tracker_at_mosque')}
                            </Button>
                        </div>
                    </>
                ) : (
                    <p className="text-sm text-muted-foreground">
                        {t('hub.tracker_waiting')}
                    </p>
                )}
            </div>
            <p className="mt-4 text-xs text-muted-foreground">
                {t('hub.tracker_humble')}
            </p>
        </section>
    );
}
