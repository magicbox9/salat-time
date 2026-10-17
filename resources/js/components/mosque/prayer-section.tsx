import { ExternalLink } from 'lucide-react';
import { useId, useState } from 'react';
import { Checkbox } from '@/components/ui/checkbox';
import { Label } from '@/components/ui/label';
import { useT } from '@/lib/i18n';
import type { MosqueSummary } from '@/types/mosque';
import { DayPath } from './day-path';
import { NextPrayerHero } from './next-prayer-hero';
import { NoTimes } from './no-times';
import { Segmented } from './segmented';
import { MonthView, WeekView } from './timetable-views';
import { TodayGrid } from './today-grid';
import type { MosqueDetails, MosquePageProps } from './types';
import { useLiveTimes } from './use-mosque-times';

type Props = {
    mosque: MosqueDetails;
    live: MosquePageProps['live'];
    nearbyWithTimes: MosqueSummary[];
};

type View = 'today' | 'week' | 'month';

/** Prayer times in the spirit of the Mac app: countdown, today, week, month, day path. */
export function PrayerSection({
    mosque,
    live: initial,
    nearbyWithTimes,
}: Props) {
    const t = useT();
    const live = useLiveTimes(mosque.slug, initial);
    const [view, setView] = useState<View>('today');
    const [showIqama, setShowIqama] = useState(false);
    const tabs = useId();

    if (!live.today) {
        return (
            <div id="prayer-times" className="scroll-mt-40">
                <NoTimes mosque={mosque} nearby={nearbyWithTimes} />
            </div>
        );
    }

    return (
        <section
            id="prayer-times"
            aria-labelledby="prayer-times-title"
            className="scroll-mt-40 space-y-4"
        >
            <NextPrayerHero
                today={live.today}
                tomorrow={live.tomorrow}
                timezone={live.timezone}
            />

            <div className="rounded-2xl border bg-card p-4 shadow-xs sm:p-6">
                <div className="flex flex-wrap items-center justify-between gap-3">
                    <h2
                        id="prayer-times-title"
                        className="text-lg font-semibold"
                    >
                        {t('mosque.prayer_times')}
                    </h2>
                    <Segmented
                        label={t('mosque.prayer_times')}
                        idPrefix={tabs}
                        panelId={`${tabs}-panel`}
                        value={view}
                        onChange={setView}
                        options={[
                            { value: 'today', label: t('site.today') },
                            { value: 'week', label: t('mosque.week') },
                            { value: 'month', label: t('mosque.month') },
                        ]}
                    />
                </div>

                <div
                    className="mt-5"
                    id={`${tabs}-panel`}
                    role="tabpanel"
                    aria-label={t(`mosque.view_${view}`)}
                >
                    {view === 'today' && (
                        <div className="space-y-6">
                            <TodayGrid
                                today={live.today}
                                tomorrow={live.tomorrow}
                                timezone={live.timezone}
                                jumua={mosque.jumua}
                                jumuaAsDhuhr={mosque.jumua_as_dhuhr}
                            />
                            <div>
                                <h3 className="mb-2 text-sm font-medium text-muted-foreground">
                                    {t('mosque.day_path')}
                                </h3>
                                <DayPath
                                    today={live.today}
                                    tomorrow={live.tomorrow}
                                    timezone={live.timezone}
                                />
                            </div>
                        </div>
                    )}
                    {view !== 'today' && (
                        <div className="space-y-3">
                            <div className="flex items-center gap-2">
                                <Checkbox
                                    id="show-iqama"
                                    checked={showIqama}
                                    onCheckedChange={(checked) =>
                                        setShowIqama(checked === true)
                                    }
                                />
                                <Label
                                    htmlFor="show-iqama"
                                    className="text-sm font-normal"
                                >
                                    {t('mosque.show_iqama')}
                                </Label>
                            </div>
                            {view === 'week' ? (
                                <WeekView
                                    slug={mosque.slug}
                                    today={live.today.date}
                                    showIqama={showIqama}
                                />
                            ) : (
                                <MonthView
                                    slug={mosque.slug}
                                    today={live.today.date}
                                    showIqama={showIqama}
                                />
                            )}
                        </div>
                    )}
                </div>

                <p className="mt-5 flex flex-wrap items-center gap-x-1.5 text-xs text-muted-foreground">
                    {t('mosque.times_source')}
                    {mosque.mawaqit_url && (
                        <a
                            href={mosque.mawaqit_url}
                            target="_blank"
                            rel="noopener noreferrer"
                            className="inline-flex items-center gap-1 underline-offset-2 hover:text-foreground hover:underline"
                        >
                            Mawaqit
                            <ExternalLink className="size-3" />
                        </a>
                    )}
                </p>
            </div>
        </section>
    );
}
