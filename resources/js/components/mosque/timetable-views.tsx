import { usePage } from '@inertiajs/react';
import { ChevronLeft, ChevronRight } from 'lucide-react';
import { useState } from 'react';
import { Button } from '@/components/ui/button';
import { Skeleton } from '@/components/ui/skeleton';
import { useT } from '@/lib/i18n';
import {
    addDays,
    formatGregorian,
    formatHijri,
    gregorianMonthRange,
    hijriMonthRange,
} from './calendar';
import { Segmented } from './segmented';
import { TimesTable } from './times-table';
import { useTimesRange } from './use-mosque-times';

type ViewProps = { slug: string; today: string; showIqama: boolean };

/** The next seven days. */
export function WeekView({ slug, today, showIqama }: ViewProps) {
    const range = useTimesRange(slug, today, 7);

    return (
        <RangeBody
            range={range}
            today={today}
            showIqama={showIqama}
            lead="gregorian"
        />
    );
}

/** A whole month, Hijri (default, as in the Mac app) or Gregorian. */
export function MonthView({ slug, today, showIqama }: ViewProps) {
    const t = useT();
    const { locale } = usePage().props;
    const [mode, setMode] = useState<'hijri' | 'gregorian'>('hijri');
    const [anchor, setAnchor] = useState(today);
    const month =
        mode === 'hijri'
            ? hijriMonthRange(anchor)
            : gregorianMonthRange(anchor);
    const end = addDays(month.start, month.days - 1);
    const range = useTimesRange(slug, month.start, month.days);
    const containsToday = today >= month.start && today <= end;

    const title =
        mode === 'hijri'
            ? formatHijri(month.start, locale, {
                  month: 'long',
                  year: 'numeric',
              })
            : formatGregorian(month.start, locale, {
                  month: 'long',
                  year: 'numeric',
              });
    const span =
        mode === 'hijri'
            ? `${formatGregorian(month.start, locale, { day: 'numeric', month: 'short' })} – ${formatGregorian(end, locale, { day: 'numeric', month: 'short', year: 'numeric' })}`
            : `${formatHijri(month.start, locale, { day: 'numeric', month: 'short' })} – ${formatHijri(end, locale, { day: 'numeric', month: 'short', year: 'numeric' })}`;

    return (
        <div className="space-y-3">
            <div className="flex flex-wrap items-center justify-between gap-3">
                <div className="flex items-center gap-1">
                    <Button
                        variant="ghost"
                        size="icon"
                        aria-label={t('mosque.previous_month')}
                        onClick={() => setAnchor(addDays(month.start, -1))}
                    >
                        <ChevronLeft className="size-4 rtl:rotate-180" />
                    </Button>
                    <div className="min-w-0 px-1 text-center">
                        <p className="font-semibold">{title}</p>
                        <p className="text-xs text-muted-foreground">{span}</p>
                    </div>
                    <Button
                        variant="ghost"
                        size="icon"
                        aria-label={t('mosque.next_month')}
                        onClick={() =>
                            setAnchor(addDays(month.start, month.days))
                        }
                    >
                        <ChevronRight className="size-4 rtl:rotate-180" />
                    </Button>
                    {!containsToday && (
                        <Button
                            variant="link"
                            size="sm"
                            onClick={() => setAnchor(today)}
                        >
                            {t('site.today')}
                        </Button>
                    )}
                </div>
                <Segmented
                    size="sm"
                    label={t('mosque.calendar')}
                    value={mode}
                    onChange={setMode}
                    options={[
                        { value: 'hijri', label: t('mosque.hijri') },
                        { value: 'gregorian', label: t('mosque.gregorian') },
                    ]}
                />
            </div>
            <RangeBody
                range={range}
                today={today}
                showIqama={showIqama}
                lead={mode}
            />
        </div>
    );
}

function RangeBody({
    range,
    today,
    showIqama,
    lead,
}: {
    range: ReturnType<typeof useTimesRange>;
    today: string;
    showIqama: boolean;
    lead: 'hijri' | 'gregorian';
}) {
    const t = useT();

    if (range.loading) {
        return (
            <div
                className="space-y-2"
                aria-busy="true"
                aria-label={t('site.loading')}
            >
                {Array.from({ length: 6 }, (_, i) => (
                    <Skeleton key={i} className="h-9 w-full rounded-lg" />
                ))}
            </div>
        );
    }

    if (range.failed || range.days.length === 0) {
        return (
            <p className="rounded-xl border border-dashed px-4 py-6 text-center text-sm text-muted-foreground">
                {range.failed ? t('site.error_generic') : t('site.no_times')}
            </p>
        );
    }

    return (
        <TimesTable
            days={range.days}
            today={today}
            showIqama={showIqama}
            lead={lead}
        />
    );
}
