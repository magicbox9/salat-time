import { usePage } from '@inertiajs/react';
import { useT } from '@/lib/i18n';
import { cn } from '@/lib/utils';
import type { DayTimes } from '@/types/mosque';
import { PRAYERS } from '@/types/mosque';
import { formatGregorian, formatHijri, isFriday } from './calendar';

type Props = {
    days: DayTimes[];
    today: string;
    showIqama: boolean;
    /** Which calendar leads the date column. */
    lead: 'hijri' | 'gregorian';
};

/** A run of published days as a table, scrollable on narrow screens. */
export function TimesTable({ days, today, showIqama, lead }: Props) {
    const t = useT();
    const { locale } = usePage().props;

    return (
        <div className="overflow-x-auto rounded-xl border">
            <table className="w-full min-w-[34rem] border-collapse text-sm">
                <thead>
                    <tr className="bg-muted/60 text-xs text-muted-foreground">
                        <th
                            scope="col"
                            className="sticky start-0 z-10 bg-muted px-3 py-2 text-start font-medium"
                        >
                            {t('mosque.day')}
                        </th>
                        {PRAYERS.map((prayer) => (
                            <th
                                key={prayer}
                                scope="col"
                                className="px-2 py-2 text-center font-medium"
                            >
                                {t(`site.prayer_${prayer}`)}
                            </th>
                        ))}
                    </tr>
                </thead>
                <tbody>
                    {days.map((day) => {
                        const isToday = day.date === today;
                        const friday = isFriday(day.date);
                        const gregorian = formatGregorian(day.date, locale, {
                            weekday: 'short',
                            day: 'numeric',
                            month: 'short',
                        });
                        const hijri = formatHijri(day.date, locale, {
                            day: 'numeric',
                            month: 'short',
                        });

                        return (
                            <tr
                                key={day.date}
                                aria-current={isToday ? 'date' : undefined}
                                className={cn(
                                    'border-t',
                                    friday && 'bg-gold/5',
                                    isToday && 'bg-primary/10 font-semibold',
                                )}
                            >
                                <th
                                    scope="row"
                                    className={cn(
                                        'sticky start-0 z-10 px-3 py-2 text-start font-normal whitespace-nowrap',
                                        isToday
                                            ? 'bg-[color-mix(in_oklab,var(--primary)_10%,var(--card))]'
                                            : 'bg-card',
                                    )}
                                >
                                    <span
                                        className={cn(
                                            'block',
                                            isToday &&
                                                'font-semibold text-primary',
                                        )}
                                    >
                                        {lead === 'hijri' ? hijri : gregorian}
                                    </span>
                                    <span className="block text-xs text-muted-foreground">
                                        {lead === 'hijri' ? gregorian : hijri}
                                        {friday && day.jumua && (
                                            <span
                                                className="ms-1.5 text-gold"
                                                role="img"
                                                title={t('site.prayer_jumua')}
                                                aria-label={t(
                                                    'site.prayer_jumua',
                                                )}
                                            >
                                                ●
                                            </span>
                                        )}
                                    </span>
                                </th>
                                {PRAYERS.map((prayer) => {
                                    const iqama =
                                        prayer === 'shuruq'
                                            ? null
                                            : day.iqama[prayer];

                                    return (
                                        <td
                                            key={prayer}
                                            className={cn(
                                                'px-2 py-2 text-center tabular-nums',
                                                prayer === 'shuruq' &&
                                                    'text-muted-foreground',
                                            )}
                                            dir="ltr"
                                        >
                                            {day.times[prayer]}
                                            {showIqama && iqama && (
                                                <span className="block text-[11px] font-normal text-muted-foreground">
                                                    {iqama}
                                                </span>
                                            )}
                                        </td>
                                    );
                                })}
                            </tr>
                        );
                    })}
                </tbody>
            </table>
        </div>
    );
}
