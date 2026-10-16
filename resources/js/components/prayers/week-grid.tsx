import { usePage } from '@inertiajs/react';
import { intlLocale, useT } from '@/lib/i18n';
import { cn } from '@/lib/utils';
import { formatDay, STATUS_STYLE } from './tracker-utils';
import type { CheckInTarget, TrackerDay } from './types';
import { STATUSES, TRACKED_PRAYERS } from './types';

type Props = {
    week: TrackerDay[];
    today: string;
    editableFrom: string;
    onOpen: (target: CheckInTarget) => void;
};

/** The last seven days × five prayers, coloured by status. Past cells can be filled in. */
export function WeekGrid({ week, today, editableFrom, onOpen }: Props) {
    const t = useT();
    const { locale } = usePage().props;
    const lang = intlLocale(locale);

    return (
        <section
            className="rounded-xl border bg-card p-4 shadow-sm sm:p-5"
            aria-labelledby="week-heading"
        >
            <div className="mb-4 flex flex-wrap items-baseline justify-between gap-2">
                <h2 id="week-heading" className="text-lg font-semibold">
                    {t('prayers.week_title')}
                </h2>
                <p className="text-xs text-muted-foreground">
                    {t('prayers.week_hint')}
                </p>
            </div>

            <div className="grid grid-cols-[3.75rem_repeat(7,minmax(0,1fr))] items-center gap-1.5 sm:grid-cols-[5rem_repeat(7,minmax(0,1fr))] sm:gap-2">
                <span />
                {week.map((day) => (
                    <div
                        key={day.date}
                        className={cn(
                            'text-center text-[11px] leading-tight text-muted-foreground sm:text-xs',
                            day.date === today && 'font-semibold text-primary',
                        )}
                    >
                        <div>
                            {formatDay(day.date, lang, { weekday: 'short' })}
                        </div>
                        <div className="tabular-nums">
                            {formatDay(day.date, lang, { day: 'numeric' })}
                        </div>
                    </div>
                ))}

                {TRACKED_PRAYERS.map((prayer) => (
                    <WeekRow
                        key={prayer}
                        prayer={prayer}
                        week={week}
                        canEdit={(date) =>
                            date >= editableFrom && date <= today
                        }
                        label={t(`site.prayer_${prayer}`)}
                        lang={lang}
                        onOpen={onOpen}
                    />
                ))}
            </div>

            <ul className="mt-4 flex flex-wrap gap-x-4 gap-y-1.5 text-xs text-muted-foreground">
                {STATUSES.map((status) => (
                    <li key={status} className="flex items-center gap-1.5">
                        <span
                            className={cn(
                                'size-2.5 rounded-sm',
                                STATUS_STYLE[status].dot,
                            )}
                        />
                        {t(`prayers.status_${status}`)}
                    </li>
                ))}
                <li className="flex items-center gap-1.5">
                    <span className="size-2.5 rounded-sm border border-dashed border-muted-foreground/50" />
                    {t('prayers.status_none')}
                </li>
            </ul>
        </section>
    );
}

type RowProps = {
    prayer: (typeof TRACKED_PRAYERS)[number];
    week: TrackerDay[];
    canEdit: (date: string) => boolean;
    label: string;
    lang: string;
    onOpen: (target: CheckInTarget) => void;
};

function WeekRow({ prayer, week, canEdit, label, lang, onOpen }: RowProps) {
    const t = useT();

    return (
        <>
            <span className="truncate text-xs font-medium sm:text-sm">
                {label}
            </span>
            {week.map((day) => {
                const log = day.prayers[prayer];
                const editable = canEdit(day.date);
                const when = formatDay(day.date, lang, {
                    weekday: 'long',
                    day: 'numeric',
                    month: 'long',
                });
                const title = `${label} · ${when} · ${log ? t(`prayers.status_${log.status}`) : t('prayers.status_none')}`;

                return (
                    <button
                        key={day.date}
                        type="button"
                        disabled={!editable}
                        title={title}
                        aria-label={title}
                        onClick={() =>
                            onOpen({
                                date: day.date,
                                prayer,
                                log,
                                suggested: 'on_time',
                            })
                        }
                        className={cn(
                            'mx-auto aspect-square w-full max-w-10 rounded-md border transition',
                            log
                                ? STATUS_STYLE[log.status].cell
                                : 'border-dashed border-muted-foreground/40 bg-transparent',
                            editable
                                ? 'cursor-pointer hover:scale-105 hover:ring-2 hover:ring-primary/30 focus-visible:ring-2 focus-visible:ring-ring focus-visible:outline-none'
                                : 'cursor-default opacity-60',
                        )}
                    />
                );
            })}
        </>
    );
}
