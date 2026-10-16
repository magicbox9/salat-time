import { router, usePage } from '@inertiajs/react';
import { ChevronLeft, ChevronRight } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { intlLocale, useT } from '@/lib/i18n';
import { cn } from '@/lib/utils';
import { deviceTimezone, formatDay } from './tracker-utils';
import type { TrackerPageProps } from './types';

/** First day of the week per language (0 = Sunday, 1 = Monday, 6 = Saturday). */
const WEEK_START: Record<string, number> = { en: 0, fr: 1, ar: 6 };

const LEVELS = [
    'bg-muted',
    'bg-primary/15',
    'bg-primary/30',
    'bg-primary/50',
    'bg-primary/70',
    'bg-primary',
];

type Props = {
    month: TrackerPageProps['month'];
    today: string;
};

/** A calendar month: the darker the day, the more of its five prayers were prayed. */
export function MonthHeatmap({ month, today }: Props) {
    const t = useT();
    const { locale } = usePage().props;
    const lang = intlLocale(locale);
    const start = WEEK_START[locale] ?? 1;
    const [y, m] = month.month.split('-').map(Number);
    const firstWeekday = new Date(Date.UTC(y, m - 1, 1)).getUTCDay();
    const offset = (firstWeekday - start + 7) % 7;
    const weekdays = Array.from({ length: 7 }, (_, i) =>
        // 2023-01-01 was a Sunday.
        formatDay(`2023-01-0${1 + ((start + i) % 7)}`, lang, {
            weekday: 'narrow',
        }),
    );
    const title = new Intl.DateTimeFormat(lang, {
        month: 'long',
        year: 'numeric',
        timeZone: 'UTC',
    }).format(new Date(Date.UTC(y, m - 1, 1)));

    const go = (value: string | null) => {
        if (value) {
            router.get(
                '/prayers',
                { month: value, tz: deviceTimezone() },
                {
                    only: ['month'],
                    preserveState: true,
                    preserveScroll: true,
                    replace: true,
                },
            );
        }
    };

    return (
        <section
            className="rounded-xl border bg-card p-4 shadow-sm sm:p-5"
            aria-labelledby="month-heading"
        >
            <div className="mb-3 flex items-center justify-between gap-2">
                <h2 id="month-heading" className="font-semibold capitalize">
                    {title}
                </h2>
                <div className="flex gap-1">
                    <Button
                        variant="ghost"
                        size="icon"
                        className="size-8"
                        disabled={!month.previous}
                        onClick={() => go(month.previous)}
                        aria-label={t('prayers.month_previous')}
                    >
                        <ChevronLeft className="size-4 rtl:rotate-180" />
                    </Button>
                    <Button
                        variant="ghost"
                        size="icon"
                        className="size-8"
                        disabled={!month.next}
                        onClick={() => go(month.next)}
                        aria-label={t('prayers.month_next')}
                    >
                        <ChevronRight className="size-4 rtl:rotate-180" />
                    </Button>
                </div>
            </div>

            <div className="grid grid-cols-7 gap-1.5 text-center">
                {weekdays.map((name, i) => (
                    <span
                        key={i}
                        className="pb-1 text-[11px] font-medium text-muted-foreground"
                    >
                        {name}
                    </span>
                ))}
                {Array.from({ length: offset }, (_, i) => (
                    <span key={`pad-${i}`} />
                ))}
                {month.days.map((day) => {
                    const future = day.date > today;
                    const label = t('prayers.month_cell', {
                        date: formatDay(day.date, lang, {
                            day: 'numeric',
                            month: 'long',
                        }),
                        prayed: day.prayed,
                        hasanat: day.hasanat,
                    });

                    return (
                        <span
                            key={day.date}
                            role={future ? undefined : 'img'}
                            title={future ? undefined : label}
                            aria-label={future ? undefined : label}
                            className={cn(
                                'flex aspect-square items-center justify-center rounded-md text-[11px] tabular-nums',
                                future
                                    ? 'border border-dashed text-muted-foreground/50'
                                    : LEVELS[Math.min(5, day.prayed)],
                                day.prayed >= 4 && 'text-primary-foreground',
                                day.date === today &&
                                    'ring-2 ring-gold ring-offset-1 ring-offset-card',
                            )}
                        >
                            {Number(day.date.slice(8))}
                        </span>
                    );
                })}
            </div>

            <div className="mt-3 flex items-center justify-end gap-1.5 text-[11px] text-muted-foreground">
                <span>{t('prayers.month_less')}</span>
                {LEVELS.map((level) => (
                    <span
                        key={level}
                        className={cn('size-3 rounded-sm', level)}
                    />
                ))}
                <span>{t('prayers.month_more')}</span>
            </div>
        </section>
    );
}
