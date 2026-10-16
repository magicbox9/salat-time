import { usePage } from '@inertiajs/react';
import { Clock } from 'lucide-react';
import { useNow } from '@/hooks/use-now';
import { useT } from '@/lib/i18n';
import {
    currentPrayer,
    formatCountdown,
    minutesInZone,
    nextPrayer,
    toMinutes,
} from '@/lib/prayer-time';
import type { DayTimes } from '@/types/mosque';
import { formatGregorian, formatHijri } from './calendar';

type Props = {
    today: DayTimes;
    tomorrow: DayTimes | null;
    timezone: string;
};

/** The big live countdown to the next prayer, with today's Gregorian and Hijri dates. */
export function NextPrayerHero({ today, tomorrow, timezone }: Props) {
    const t = useT();
    const { locale } = usePage().props;
    const now = useNow();
    const next = nextPrayer(today, tomorrow, timezone, now);
    const current = currentPrayer(today, timezone, now);
    const nowMinutes = minutesInZone(timezone, now);
    const currentIqama = current
        ? today.iqama[current as keyof DayTimes['iqama']]
        : null;
    const iqamaIn =
        currentIqama && toMinutes(currentIqama) > nowMinutes
            ? toMinutes(currentIqama) - nowMinutes
            : null;
    const nextIqama =
        next && !next.tomorrow && next.prayer !== 'shuruq'
            ? today.iqama[next.prayer as keyof DayTimes['iqama']]
            : null;
    const visitorZone =
        typeof Intl !== 'undefined'
            ? Intl.DateTimeFormat().resolvedOptions().timeZone
            : timezone;
    const localClock = new Intl.DateTimeFormat('en-GB', {
        timeZone: timezone,
        hour: '2-digit',
        minute: '2-digit',
        hourCycle: 'h23',
    }).format(now);

    return (
        <div className="relative overflow-hidden rounded-2xl bg-gradient-to-br from-[oklch(0.4_0.085_168)] via-[oklch(0.36_0.07_178)] to-[oklch(0.28_0.05_200)] p-5 text-white shadow-sm sm:p-7">
            <div
                aria-hidden="true"
                className="pointer-events-none absolute -end-16 -top-20 size-64 rounded-full bg-[radial-gradient(circle,oklch(0.85_0.12_85/0.35),transparent_65%)]"
            />
            <div className="relative flex flex-col gap-6 sm:flex-row sm:items-end sm:justify-between">
                <div>
                    <p className="text-xs font-medium tracking-wider text-white/70 uppercase">
                        {t('site.next_prayer')}
                        {next?.tomorrow && <> · {t('site.tomorrow')}</>}
                    </p>
                    {next ? (
                        <>
                            <p className="mt-1 flex items-baseline gap-3">
                                <span className="text-3xl font-semibold sm:text-4xl">
                                    {t(`site.prayer_${next.prayer}`)}
                                </span>
                                <span
                                    className="text-2xl text-gold tabular-nums sm:text-3xl"
                                    dir="ltr"
                                >
                                    {next.time}
                                </span>
                            </p>
                            <p
                                className="mt-3 font-mono text-5xl font-light tracking-tight tabular-nums sm:text-6xl"
                                dir="ltr"
                                suppressHydrationWarning
                                aria-label={t('mosque.countdown_label', {
                                    time: formatCountdown(next.inMinutes),
                                })}
                            >
                                {formatCountdown(next.inMinutes)}
                            </p>
                        </>
                    ) : (
                        <p className="mt-2 text-lg">{t('site.no_times')}</p>
                    )}
                    <div className="mt-3 flex flex-wrap gap-2 text-sm">
                        {iqamaIn !== null && current && (
                            <span className="rounded-full bg-gold/20 px-3 py-1 text-white ring-1 ring-gold/40">
                                {t('mosque.iqama_of_in', {
                                    prayer: t(`site.prayer_${current}`),
                                })}{' '}
                                <span
                                    dir="ltr"
                                    className="font-mono tabular-nums"
                                    suppressHydrationWarning
                                >
                                    {formatCountdown(iqamaIn)}
                                </span>
                            </span>
                        )}
                        {nextIqama && (
                            <span className="rounded-full bg-white/10 px-3 py-1 text-white/90">
                                {t('site.iqama')}{' '}
                                <span dir="ltr" className="tabular-nums">
                                    {nextIqama}
                                </span>
                            </span>
                        )}
                    </div>
                </div>

                <div className="space-y-1 text-sm sm:text-end">
                    <p className="font-medium text-white">
                        {formatGregorian(today.date, locale)}
                    </p>
                    <p className="text-gold">
                        {formatHijri(today.date, locale)}
                    </p>
                    {visitorZone !== timezone && (
                        <p className="flex items-center gap-1.5 text-white/70 sm:justify-end">
                            <Clock className="size-3.5" />
                            {t('mosque.local_time')}{' '}
                            <span
                                dir="ltr"
                                className="tabular-nums"
                                suppressHydrationWarning
                            >
                                {localClock}
                            </span>
                        </p>
                    )}
                </div>
            </div>
        </div>
    );
}
