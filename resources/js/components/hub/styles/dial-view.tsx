import { usePage } from '@inertiajs/react';
import { useId } from 'react';
import { useT } from '@/lib/i18n';
import { usePrayerName } from '../bits';
import { isDaytime, skyDayOf } from '../day';
import { formatClock, formatLeft } from '../format';
import { css, darkness, skyAt } from '../sky';
import type { DayView, HubPrefs } from '../types';
import {
    C,
    DISC,
    DialRing,
    dialGeometry,
    LABEL,
    RING,
    RING_WIDTH,
    SIZE,
} from './dial-ring';
import { GOLD, SkyStyles, SvgMoon, SvgStars, SvgSun } from './sky-bodies';
import { TimesStrip } from './times-strip';

type Props = { view: DayView; prefs: HubPrefs; southern: boolean; now: Date };

/**
 * "Dial": the whole day on a 24-hour clock, as the Mac app's dial —
 * midnight at the bottom, noon at the top, the ring painted with the sky's
 * colours, a window onto the sky of this minute in the middle.
 */
export function DialView({ view, prefs, southern, now }: Props) {
    const t = useT();
    const name = usePrayerName();
    const { dir, locale } = usePage().props;
    const id = useId().replace(/:/g, '');
    const day = skyDayOf(view);
    const sky = skyAt(view.nowMinutes, day);
    const rtl = dir === 'rtl';

    const { angle, at } = dialGeometry(rtl);

    const nowPoint = at(view.nowMinutes, RING);
    const current = view.rows.find((row) => row.state === 'current');
    const left = view.untilNext;

    return (
        <div className="space-y-3">
            <div className="mx-auto w-full max-w-[30rem] rounded-3xl border bg-[oklch(0.16_0.03_240)] p-2 shadow-sm sm:p-4">
                <svg
                    viewBox={`-16 -6 ${SIZE + 32} ${SIZE + 12}`}
                    className="block h-auto w-full"
                    role="img"
                    aria-label={
                        view.next
                            ? t('hub.arc_label', {
                                  prayer: name(view.next.prayer),
                                  time: formatClock(
                                      view.next.time,
                                      prefs.clock,
                                      locale,
                                  ),
                              })
                            : t('hub.style_dial')
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
                        <clipPath id={`${id}-disc`}>
                            <circle cx={C} cy={C} r={DISC} />
                        </clipPath>
                    </defs>

                    <DialRing day={day} rtl={rtl} />

                    <g clipPath={`url(#${id}-disc)`}>
                        <rect
                            x={C - DISC}
                            y={C - DISC}
                            width={DISC * 2}
                            height={DISC * 2}
                            fill={`url(#${id}-sky)`}
                        />
                        <SvgStars
                            x={C - DISC}
                            y={C - DISC}
                            width={DISC * 2}
                            height={DISC * 1.4}
                            count={40}
                            seed={3}
                            opacity={darkness(sky)}
                        />
                        {isDaytime(view) ? (
                            <SvgSun
                                cx={C}
                                cy={C - DISC * 0.5}
                                r={DISC * 0.12}
                            />
                        ) : (
                            <SvgMoon
                                cx={C}
                                cy={C - DISC * 0.5}
                                r={DISC * 0.14}
                                at={now}
                                southern={southern}
                            />
                        )}
                        <rect
                            x={C - DISC}
                            y={C + DISC * 0.62}
                            width={DISC * 2}
                            height={DISC}
                            fill="black"
                            opacity={0.28}
                        />
                    </g>
                    <circle
                        cx={C}
                        cy={C}
                        r={DISC}
                        fill="none"
                        stroke="white"
                        strokeOpacity={0.25}
                    />

                    <text
                        x={C}
                        y={C + 10}
                        textAnchor="middle"
                        fontSize={13}
                        fontWeight={600}
                        fill="white"
                        fillOpacity={0.88}
                    >
                        {current
                            ? t('hub.dial_now', {
                                  prayer: name(current.prayer),
                              })
                            : view.next
                              ? t('hub.dial_until', {
                                    prayer: name(view.next.prayer),
                                })
                              : ''}
                    </text>
                    {left !== null && (
                        <text
                            x={C}
                            y={C + 40}
                            textAnchor="middle"
                            fontSize={26}
                            fontWeight={700}
                            fill="white"
                            direction="ltr"
                            style={{ fontVariantNumeric: 'tabular-nums' }}
                        >
                            {formatLeft(left, prefs.show_seconds)}
                        </text>
                    )}

                    {view.rows.map((row) => {
                        const minute = row.minutes;
                        const dot = at(minute, RING);
                        const label = at(minute, LABEL);
                        const cos = Math.cos(angle(minute));
                        const anchor =
                            cos > 0.35
                                ? 'start'
                                : cos < -0.35
                                  ? 'end'
                                  : 'middle';
                        const isNext = row.state === 'next';

                        return (
                            <g key={row.prayer}>
                                <circle
                                    cx={dot.x}
                                    cy={dot.y}
                                    r={isNext ? 7 : 5}
                                    fill={
                                        row.state === 'passed' ||
                                        row.state === 'current'
                                            ? GOLD
                                            : 'rgb(20 30 45)'
                                    }
                                    stroke={isNext ? GOLD : 'white'}
                                    strokeWidth={isNext ? 3 : 1.5}
                                />
                                <text
                                    x={label.x}
                                    y={label.y - 3}
                                    textAnchor={anchor}
                                    direction="ltr"
                                    fontSize={13}
                                    fontWeight={isNext ? 700 : 500}
                                    fill="white"
                                    fillOpacity={isNext ? 1 : 0.85}
                                >
                                    {name(row.prayer)}
                                </text>
                                <text
                                    x={label.x}
                                    y={label.y + 12}
                                    textAnchor={anchor}
                                    fontSize={12.5}
                                    fill={isNext ? GOLD : 'white'}
                                    fillOpacity={isNext ? 1 : 0.7}
                                    direction="ltr"
                                    style={{
                                        fontVariantNumeric: 'tabular-nums',
                                    }}
                                >
                                    {formatClock(
                                        view.today.times[row.prayer],
                                        prefs.clock,
                                        locale,
                                    )}
                                </text>
                            </g>
                        );
                    })}

                    <circle
                        cx={nowPoint.x}
                        cy={nowPoint.y}
                        r={RING_WIDTH / 2 + 2}
                        fill="none"
                        stroke="white"
                        strokeWidth={2.5}
                    />
                    <circle
                        cx={nowPoint.x}
                        cy={nowPoint.y}
                        r={3}
                        fill="white"
                    />
                </svg>
            </div>
            <TimesStrip view={view} prefs={prefs} />
        </div>
    );
}
