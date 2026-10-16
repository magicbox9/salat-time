import {
    Building2,
    Check,
    Home,
    MapPin,
    Pencil,
    Undo2,
    Users,
} from 'lucide-react';
import { useState } from 'react';
import { Button } from '@/components/ui/button';
import {
    Tooltip,
    TooltipContent,
    TooltipTrigger,
} from '@/components/ui/tooltip';
import { useT } from '@/lib/i18n';
import { cn } from '@/lib/utils';
import type { DayTimes } from '@/types/mosque';
import type { PrayerWindow } from './tracker-utils';
import { QuickCheckIn } from './quick-check-in';
import {
    HASANAT_TEXT,
    removeLog,
    STATUS_STYLE,
    suggestStatus,
} from './tracker-utils';
import type { LogPlace, PrayerLogData, TrackedPrayer } from './types';

const PLACE_ICON: Record<LogPlace, typeof Home> = {
    mosque: Building2,
    home: Home,
    work: MapPin,
    other: MapPin,
};

type Props = {
    prayer: TrackedPrayer;
    date: string;
    log: PrayerLogData | null;
    times: DayTimes | null;
    window: PrayerWindow;
    onOpen: () => void;
};

/** One of today's prayers: its time, its check-in, and quick actions. */
export function PrayerRow({ prayer, date, log, times, window, onOpen }: Props) {
    const t = useT();
    const [busy, setBusy] = useState(false);
    const time = times?.times[prayer];
    const iqama = times?.iqama[prayer];

    const PlaceIcon = log ? PLACE_ICON[log.place] : Home;

    return (
        <li
            className={cn(
                'flex flex-wrap items-center gap-x-4 gap-y-3 px-4 py-3.5 sm:px-5',
                window === 'current' && !log && 'bg-primary/5',
            )}
        >
            <div className="flex min-w-0 flex-1 items-center gap-3">
                <span
                    className={cn(
                        'flex size-9 shrink-0 items-center justify-center rounded-full border',
                        log
                            ? cn(STATUS_STYLE[log.status].cell, 'text-white')
                            : 'border-dashed text-muted-foreground',
                    )}
                    aria-hidden
                >
                    {log && log.status !== 'missed' ? (
                        <Check className="size-4" />
                    ) : null}
                </span>
                <div className="min-w-0">
                    <p className="flex items-center gap-2 font-medium">
                        {t(`site.prayer_${prayer}`)}
                        {window === 'current' && (
                            <span className="rounded-full bg-primary/12 px-2 py-0.5 text-[11px] font-medium text-primary">
                                {t('prayers.window_now')}
                            </span>
                        )}
                    </p>
                    {time ? (
                        <p className="text-xs text-muted-foreground">
                            <span dir="ltr" className="tabular-nums">
                                {time}
                            </span>
                            {iqama && (
                                <>
                                    {' · '}
                                    {t('site.iqama')}{' '}
                                    <span dir="ltr" className="tabular-nums">
                                        {iqama}
                                    </span>
                                </>
                            )}
                        </p>
                    ) : null}
                </div>
            </div>

            {log ? (
                <div className="flex items-center gap-2">
                    <span
                        className={cn(
                            'rounded-full border px-2.5 py-0.5 text-xs font-medium',
                            STATUS_STYLE[log.status].badge,
                        )}
                    >
                        {t(`prayers.status_${log.status}`)}
                    </span>
                    {log.status !== 'missed' && (
                        <span className="flex items-center gap-1 text-muted-foreground">
                            <Tooltip>
                                <TooltipTrigger asChild>
                                    <PlaceIcon
                                        className="size-4"
                                        aria-label={t(
                                            `prayers.place_${log.place}`,
                                        )}
                                    />
                                </TooltipTrigger>
                                <TooltipContent>
                                    {t(`prayers.place_${log.place}`)}
                                </TooltipContent>
                            </Tooltip>
                            {log.in_congregation && (
                                <Tooltip>
                                    <TooltipTrigger asChild>
                                        <Users
                                            className="size-4"
                                            aria-label={t(
                                                'prayers.field_congregation',
                                            )}
                                        />
                                    </TooltipTrigger>
                                    <TooltipContent>
                                        {t('prayers.field_congregation')}
                                    </TooltipContent>
                                </Tooltip>
                            )}
                        </span>
                    )}
                    <span
                        className={cn(
                            'min-w-10 text-end text-sm font-semibold tabular-nums',
                            HASANAT_TEXT,
                        )}
                        dir="ltr"
                    >
                        +{log.hasanat}
                    </span>
                    <Button
                        variant="ghost"
                        size="icon"
                        className="size-8"
                        onClick={onOpen}
                        aria-label={t('prayers.action_edit')}
                    >
                        <Pencil className="size-4" />
                    </Button>
                    <Button
                        variant="ghost"
                        size="icon"
                        className="size-8 text-muted-foreground"
                        disabled={busy}
                        onClick={() => {
                            setBusy(true);
                            removeLog(log.id, () => setBusy(false));
                        }}
                        aria-label={t('prayers.action_undo')}
                    >
                        <Undo2 className="size-4 rtl:-scale-x-100" />
                    </Button>
                </div>
            ) : window === 'upcoming' ? (
                <span className="text-sm text-muted-foreground">
                    {t('prayers.window_upcoming')}
                </span>
            ) : (
                <QuickCheckIn
                    date={date}
                    prayer={prayer}
                    suggested={suggestStatus(window)}
                    onDetails={onOpen}
                />
            )}
        </li>
    );
}
