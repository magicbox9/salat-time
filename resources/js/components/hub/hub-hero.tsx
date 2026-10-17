import { usePage } from '@inertiajs/react';
import { BadgeCheck, Home, MapPin } from 'lucide-react';
import type { ReactNode } from 'react';
import { dateInZone, placeLine } from '@/components/discover/format';
import { useT } from '@/lib/i18n';
import { cn } from '@/lib/utils';
import { Clock, Countdown, usePrayerName } from './bits';
import { skyDayOf } from './day';
import { formatGregorianDate, formatHijriDate, formatNow } from './format';
import { css, darkness, skyAt } from './sky';
import { SkyStyles, SvgStars } from './styles/sky-bodies';
import type { DayView, HubMosque, HubPrefs } from './types';

type Props = {
    mosque: HubMosque;
    view: DayView | null;
    prefs: HubPrefs;
    now: Date;
    /** Extra controls in the hero's corner (adhan mute). */
    corner?: ReactNode;
};

/**
 * The top of the hub: the visitor's mosque, the next prayer with a large
 * live countdown and today's Gregorian and Hijri dates, over the living sky
 * of this minute at the mosque.
 */
export function HubHero({ mosque, view, prefs, now, corner }: Props) {
    const t = useT();
    const name = usePrayerName();
    const { locale } = usePage().props;
    // The calendar date at the mosque (after midnight the evening's Isha may still show).
    const date = dateInZone(mosque.timezone, now) || view?.today.date || null;
    const place = placeLine(mosque);

    const sky = view ? skyAt(view.nowMinutes, skyDayOf(view)) : null;
    const background = sky
        ? `linear-gradient(165deg, ${css(sky.top)} 0%, ${css(sky.top, 0.92)} 45%, ${css(sky.horizon)} 100%)`
        : 'linear-gradient(150deg, oklch(0.42 0.085 168), oklch(0.32 0.06 185) 55%, oklch(0.24 0.045 210))';

    const current = view?.rows.find((row) => row.state === 'current') ?? null;
    const nowMinutes = view?.nowMinutes ?? 0;
    const iqamaIn =
        current?.iqamaAt != null && current.iqamaAt > nowMinutes
            ? current.iqamaAt - nowMinutes
            : null;
    const next = view?.next ?? null;
    // Friday: the Jumu'a time until the Dhuhr slot it replaces is over.
    const dhuhr = view?.rows.find((row) => row.prayer === 'dhuhr');
    const jumua = dhuhr?.jumua && dhuhr.state !== 'passed' ? dhuhr.jumua : null;

    return (
        <section
            aria-labelledby="hub-mosque-name"
            className="relative isolate overflow-hidden rounded-3xl text-white shadow-lg ring-1 ring-black/5"
            style={{ background }}
        >
            {sky && (
                <svg
                    aria-hidden
                    className="absolute inset-0 -z-10 h-full w-full"
                    preserveAspectRatio="xMidYMid slice"
                    viewBox="0 0 400 240"
                >
                    <SkyStyles />
                    <SvgStars
                        x={0}
                        y={0}
                        width={400}
                        height={170}
                        count={48}
                        seed={11}
                        scale={0.55}
                        opacity={darkness(sky) * 0.85}
                    />
                </svg>
            )}
            <div
                aria-hidden
                className="absolute inset-0 -z-10 bg-gradient-to-t from-black/50 via-black/15 to-black/5"
            />
            <div
                aria-hidden
                className="absolute -end-20 -top-24 -z-10 size-72 rounded-full bg-[radial-gradient(circle,oklch(0.85_0.12_85/0.28),transparent_65%)]"
            />

            <div
                className={cn(
                    'relative',
                    prefs.compact ? 'p-5 sm:p-6' : 'p-5 sm:p-8 lg:p-10',
                )}
            >
                <div className="flex flex-col gap-4 sm:flex-row sm:items-start sm:justify-between">
                    <div className="min-w-0">
                        <p className="flex items-center gap-1.5 text-xs font-semibold tracking-wider text-gold uppercase">
                            <Home className="size-3.5" aria-hidden />
                            {t('discover.my_mosque')}
                        </p>
                        <h1
                            id="hub-mosque-name"
                            className="mt-1 text-2xl leading-tight font-semibold text-balance sm:text-3xl"
                        >
                            <bdi>{mosque.name}</bdi>
                            {mosque.verified && (
                                <BadgeCheck
                                    className="ms-2 inline size-5 align-[-3px] text-gold"
                                    aria-label={t('discover.verified')}
                                />
                            )}
                        </h1>
                        {(mosque.tagline || place) && (
                            <p className="mt-1.5 flex items-start gap-1.5 text-sm text-white/75">
                                {!mosque.tagline && (
                                    <MapPin
                                        className="mt-0.5 size-3.5 shrink-0"
                                        aria-hidden
                                    />
                                )}
                                <span dir="auto">
                                    {mosque.tagline ?? place}
                                </span>
                            </p>
                        )}
                    </div>
                    <div className="flex shrink-0 items-start justify-between gap-3 sm:flex-col sm:items-end sm:text-end">
                        <div>
                            <p
                                dir="ltr"
                                suppressHydrationWarning
                                className="text-2xl font-light tabular-nums sm:text-end sm:text-3xl"
                            >
                                {formatNow(now, mosque.timezone, prefs, locale)}
                            </p>
                            {date && (
                                <>
                                    <p className="text-sm text-white/85">
                                        {formatGregorianDate(date, locale)}
                                    </p>
                                    {prefs.show_hijri && (
                                        <p className="text-sm text-gold">
                                            {formatHijriDate(date, locale)}
                                        </p>
                                    )}
                                </>
                            )}
                        </div>
                        {corner}
                    </div>
                </div>

                <div className={prefs.compact ? 'mt-6' : 'mt-8 sm:mt-12'}>
                    {/* Today's times without a next one (tomorrow not fetched yet) show no countdown — never "no times". */}
                    {next && view?.untilNext != null ? (
                        <>
                            <p className="text-xs font-medium tracking-wider text-white/70 uppercase">
                                {t('site.next_prayer')}
                                {next.tomorrow && <> · {t('site.tomorrow')}</>}
                            </p>
                            <p className="mt-1 flex flex-wrap items-baseline gap-x-3">
                                <span className="text-3xl font-semibold sm:text-4xl">
                                    {name(next.prayer)}
                                </span>
                                <Clock
                                    value={next.time}
                                    prefs={prefs}
                                    className="text-2xl text-gold sm:text-3xl"
                                />
                            </p>
                            <p
                                className={cn(
                                    'mt-2 font-extralight tracking-tight',
                                    prefs.compact
                                        ? 'text-5xl'
                                        : 'text-6xl sm:text-7xl lg:text-8xl',
                                )}
                                aria-live="off"
                            >
                                <Countdown
                                    minutes={view.untilNext}
                                    prefs={prefs}
                                    className="font-sans"
                                />
                            </p>
                        </>
                    ) : view ? null : (
                        <p className="max-w-xl text-lg text-white/90">
                            {t(
                                mosque.has_times
                                    ? 'hub.no_times_today_hero'
                                    : 'hub.no_times_hero',
                            )}
                        </p>
                    )}

                    {(iqamaIn !== null ||
                        (next && next.iqama && prefs.show_iqama) ||
                        jumua) && (
                        <div className="mt-4 flex flex-wrap gap-2 text-sm">
                            {iqamaIn !== null && current && (
                                <span className="rounded-full bg-gold/25 px-3 py-1 ring-1 ring-gold/50">
                                    {t('hub.iqama_in', {
                                        prayer: name(current.prayer),
                                    })}{' '}
                                    <Countdown
                                        minutes={iqamaIn}
                                        prefs={prefs}
                                    />
                                </span>
                            )}
                            {next?.iqama && prefs.show_iqama && (
                                <span className="rounded-full bg-white/12 px-3 py-1 ring-1 ring-white/20">
                                    {t('site.iqama')}{' '}
                                    <Clock value={next.iqama} prefs={prefs} />
                                </span>
                            )}
                            {jumua && (
                                <span className="rounded-full bg-white/12 px-3 py-1 ring-1 ring-white/20">
                                    {t('site.prayer_jumua')}{' '}
                                    <Clock value={jumua} prefs={prefs} />
                                </span>
                            )}
                        </div>
                    )}
                </div>
            </div>
        </section>
    );
}
