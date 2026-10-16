import { usePage } from '@inertiajs/react';
import type { LucideIcon } from 'lucide-react';
import {
    MoonStar,
    Sun,
    SunDim,
    SunMedium,
    Sunrise,
    Sunset,
} from 'lucide-react';
import { useT } from '@/lib/i18n';
import { cn } from '@/lib/utils';
import type { PrayerName } from '@/types/mosque';
import { formatClock, formatLeft } from './format';
import type { HubPrefs, TimeRow } from './types';

export const PRAYER_ICON: Record<PrayerName, LucideIcon> = {
    fajr: SunDim,
    shuruq: Sunrise,
    dhuhr: Sun,
    asr: SunMedium,
    maghrib: Sunset,
    isha: MoonStar,
};

/** A published time in the chosen 12/24 h style, always left-to-right. */
export function Clock({
    value,
    prefs,
    className,
}: {
    value: string;
    prefs: Pick<HubPrefs, 'clock'>;
    className?: string;
}) {
    const { locale } = usePage().props;

    return (
        <span dir="ltr" className={cn('tabular-nums', className)}>
            {formatClock(value, prefs.clock, locale)}
        </span>
    );
}

/** A live countdown ("1:12:05", or "1:13" without seconds). */
export function Countdown({
    minutes,
    prefs,
    className,
}: {
    minutes: number;
    prefs: Pick<HubPrefs, 'show_seconds'>;
    className?: string;
}) {
    return (
        <span
            dir="ltr"
            suppressHydrationWarning
            className={cn('font-mono tabular-nums', className)}
        >
            {formatLeft(minutes, prefs.show_seconds)}
        </span>
    );
}

/** "Iqama 13:10" / "Jumu'a 13:30" under a time. */
export function RowExtras({
    row,
    prefs,
    className,
}: {
    row: TimeRow;
    prefs: HubPrefs;
    className?: string;
}) {
    const t = useT();
    const iqama = prefs.show_iqama ? row.iqama : null;

    if (!iqama && !row.jumua && !row.tomorrow) {
        return null;
    }

    return (
        <span
            className={cn(
                'flex flex-wrap items-center gap-x-2 gap-y-0.5',
                className,
            )}
        >
            {row.tomorrow && <span>{t('site.tomorrow')}</span>}
            {iqama && (
                <span>
                    {t('site.iqama')} <Clock value={iqama} prefs={prefs} />
                </span>
            )}
            {row.jumua && (
                <span className="font-medium text-gold">
                    {t('site.prayer_jumua')}{' '}
                    <Clock value={row.jumua} prefs={prefs} />
                </span>
            )}
        </span>
    );
}

/** The prayer's translated name. */
export function usePrayerName() {
    const t = useT();

    return (prayer: PrayerName) => t(`site.prayer_${prayer}`);
}
