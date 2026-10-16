import { usePage } from '@inertiajs/react';
import { useId } from 'react';
import { useT } from '@/lib/i18n';
import { formatClock } from '../format';
import { usePrayerName } from '../bits';
import { isDaytime, skyDayOf } from '../day';
import { css, darkness, skyAt } from '../sky';
import type { DayView, HubPrefs } from '../types';
import { GOLD, SkyStyles, SvgMoon, SvgStars, SvgSun } from './sky-bodies';
import { TimesStrip } from './times-strip';

type Props = { view: DayView; prefs: HubPrefs; southern: boolean; now: Date };

const W = 360;
const H = 250;
const HORIZON = 146;
const PEAK = 104;
const DIP = 20;
const PAD = 24;
/** Label rows under the horizon, alternating so close times never overlap. */
const LABEL_ROWS = [186, 220];

/**
 * "Sky arc": the day's path of the sun as in the Mac app — dawn rising to
 * sunrise, the arc over Dhuhr and Asr, dusk after Maghrib — on the living
 * sky of this very minute. The lived part of the path glows gold.
 */
export function ArcView({ view, prefs, southern, now }: Props) {
    const t = useT();
    const name = usePrayerName();
    const { dir, locale } = usePage().props;
    const id = useId().replace(/:/g, '');
    // The Fajr row may show tomorrow's time after Isha: today's minute drives the path.
    const skyDay = skyDayOf(view);
    const { fajr, shuruq, maghrib, isha } = skyDay;
    const start = fajr - 50;
    const end = isha + 50;
    const sky = skyAt(view.nowMinutes, skyDay);
    const dark = darkness(sky);

    const x = (minute: number) => {
        const value =
            PAD + ((minute - start) / Math.max(1, end - start)) * (W - 2 * PAD);

        return dir === 'rtl' ? W - value : value;
    };
    const y = (minute: number) => {
        if (minute <= shuruq) {
            const f = Math.max(0, (minute - fajr) / Math.max(1, shuruq - fajr));

            return HORIZON + DIP * Math.cos((f * Math.PI) / 2);
        }

        if (minute <= maghrib) {
            return (
                HORIZON -
                PEAK *
                    Math.sin(
                        (Math.PI * (minute - shuruq)) /
                            Math.max(1, maghrib - shuruq),
                    )
            );
        }

        const f = Math.min(1, (minute - maghrib) / Math.max(1, isha - maghrib));

        return HORIZON + DIP * Math.sin((f * Math.PI) / 2);
    };
    const points = (from: number, to: number) => {
        const out: string[] = [];

        for (let minute = from; minute < to; minute += 4) {
            out.push(`${x(minute).toFixed(1)},${y(minute).toFixed(1)}`);
        }

        out.push(`${x(to).toFixed(1)},${y(to).toFixed(1)}`);

        return out.join(' ');
    };

    const nowClamped = Math.min(Math.max(view.nowMinutes, fajr), isha);
    const lived = view.nowMinutes > fajr ? points(fajr, nowClamped) : null;
    const day = isDaytime(view);
    const next = view.next;

    return (
        <div className="space-y-3">
            <div className="overflow-hidden rounded-2xl border shadow-sm">
                <svg
                    viewBox={`0 0 ${W} ${H}`}
                    className="block h-auto w-full"
                    role="img"
                    aria-label={
                        next
                            ? t('hub.arc_label', {
                                  prayer: name(next.prayer),
                                  time: formatClock(
                                      next.time,
                                      prefs.clock,
                                      locale,
                                  ),
                              })
                            : t('hub.style_arc')
                    }
                >
                    <SkyStyles />
                    <defs>
                        <linearGradient
                            id={`${id}-sky`}
                            x1="0"
                            y1="0"
                            x2="0"
                            y2="1"
                        >
                            <stop offset="0%" stopColor={css(sky.top)} />
                            <stop offset="100%" stopColor={css(sky.horizon)} />
                        </linearGradient>
                    </defs>
                    <rect width={W} height={HORIZON} fill={`url(#${id}-sky)`} />
                    <SvgStars
                        x={0}
                        y={0}
                        width={W}
                        height={HORIZON - 20}
                        count={46}
                        seed={7}
                        opacity={dark}
                    />
                    <rect
                        y={HORIZON}
                        width={W}
                        height={H - HORIZON}
                        fill={css(sky.horizon)}
                    />
                    <rect
                        y={HORIZON}
                        width={W}
                        height={H - HORIZON}
                        fill="black"
                        opacity={0.42}
                    />
                    <line
                        x1={0}
                        x2={W}
                        y1={HORIZON}
                        y2={HORIZON}
                        stroke="white"
                        strokeOpacity={0.3}
                    />

                    <polyline
                        points={points(fajr, shuruq)}
                        fill="none"
                        stroke="white"
                        strokeOpacity={0.4}
                        strokeDasharray="3 4"
                    />
                    <polyline
                        points={points(shuruq, maghrib)}
                        fill="none"
                        stroke="white"
                        strokeOpacity={0.55}
                        strokeWidth={1.5}
                    />
                    <polyline
                        points={points(maghrib, isha)}
                        fill="none"
                        stroke="white"
                        strokeOpacity={0.4}
                        strokeDasharray="3 4"
                    />
                    {lived && (
                        <polyline
                            points={lived}
                            fill="none"
                            stroke={GOLD}
                            strokeWidth={2.75}
                            strokeLinecap="round"
                            pathLength={1}
                            className="hub-draw"
                        />
                    )}

                    {view.rows.map((row, i) => {
                        const minute =
                            row.prayer === 'fajr' ? fajr : row.minutes;
                        const px = x(minute);
                        const low = i % 2 === 1;
                        const isNext = row.state === 'next';

                        return (
                            <g key={row.prayer}>
                                <line
                                    x1={px}
                                    x2={px}
                                    y1={y(minute) + 6}
                                    y2={LABEL_ROWS[low ? 1 : 0] - 12}
                                    stroke="white"
                                    strokeOpacity={0.18}
                                    strokeDasharray="2 3"
                                />
                                <circle
                                    cx={px}
                                    cy={y(minute)}
                                    r={isNext ? 5.5 : 4}
                                    fill={
                                        row.state === 'passed' ||
                                        row.state === 'current'
                                            ? GOLD
                                            : 'rgb(255 255 255 / 0.15)'
                                    }
                                    stroke={isNext ? GOLD : 'white'}
                                    strokeWidth={isNext ? 2.5 : 1.2}
                                />
                                <text
                                    x={px}
                                    y={LABEL_ROWS[low ? 1 : 0]}
                                    textAnchor="middle"
                                    fontSize={10}
                                    fill="white"
                                    fillOpacity={0.8}
                                    fontWeight={isNext ? 700 : 500}
                                >
                                    {name(row.prayer)}
                                </text>
                                <text
                                    x={px}
                                    y={LABEL_ROWS[low ? 1 : 0] + 14}
                                    textAnchor="middle"
                                    fontSize={11.5}
                                    fill={isNext ? GOLD : 'white'}
                                    fontWeight={isNext ? 700 : 400}
                                    direction="ltr"
                                    style={{
                                        fontVariantNumeric: 'tabular-nums',
                                    }}
                                >
                                    {formatClock(
                                        row.prayer === 'fajr'
                                            ? view.today.times.fajr
                                            : row.time,
                                        prefs.clock,
                                        locale,
                                    )}
                                </text>
                            </g>
                        );
                    })}

                    {day ? (
                        <SvgSun
                            cx={x(view.nowMinutes)}
                            cy={y(view.nowMinutes)}
                            r={8}
                        />
                    ) : (
                        <>
                            {view.nowMinutes > fajr &&
                                view.nowMinutes < isha && (
                                    <circle
                                        cx={x(view.nowMinutes)}
                                        cy={y(view.nowMinutes)}
                                        r={3.5}
                                        fill="white"
                                    />
                                )}
                            <SvgMoon
                                cx={dir === 'rtl' ? 44 : W - 44}
                                cy={42}
                                r={12}
                                at={now}
                                southern={southern}
                            />
                        </>
                    )}
                </svg>
            </div>
            <TimesStrip view={view} prefs={prefs} />
        </div>
    );
}
