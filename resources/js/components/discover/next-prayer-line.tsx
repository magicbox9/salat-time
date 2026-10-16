import { Clock } from 'lucide-react';
import { useNow } from '@/hooks/use-now';
import { useT } from '@/lib/i18n';
import { formatCountdown, nextPrayer } from '@/lib/prayer-time';
import { cn } from '@/lib/utils';
import { currentDays, dateInZone } from './format';
import type { DayTimesLite } from './types';

const MARK = '\u2063';

type Props = {
    today: DayTimesLite | null;
    tomorrow: DayTimesLite | null;
    timezone: string;
    className?: string;
};

/** "Asr 16:26 · 1:12:05" — the next published prayer with a live countdown (nothing when unpublished). */
export function NextPrayerLine({
    today,
    tomorrow,
    timezone,
    className,
}: Props) {
    const t = useT();
    const now = useNow();
    // Only `times` is read; iqama and Jumu'a are not needed for the countdown.
    const full = (day: DayTimesLite | null) =>
        day ? { ...day, iqama: {}, jumua: null } : null;
    // A page left open past midnight moves on to the next published day.
    const [day, following] = currentDays(
        today,
        tomorrow,
        dateInZone(timezone, now),
    );
    const next = nextPrayer(full(day), full(following), timezone, now);

    if (!next) {
        return null;
    }

    return (
        <p className={cn('flex items-center gap-1.5 text-sm', className)}>
            <Clock className="size-3.5 shrink-0 text-primary" aria-hidden />
            <span className="font-medium">
                {t(`site.prayer_${next.prayer}`)}
            </span>
            <span dir="ltr" className="text-muted-foreground tabular-nums">
                {next.time}
            </span>
            <span aria-hidden className="text-muted-foreground">
                ·
            </span>
            <span className="text-primary">
                <InTime
                    label={t('site.in_time', { time: MARK })}
                    countdown={formatCountdown(next.inMinutes)}
                />
            </span>
        </p>
    );
}

/** "in {time}" with the countdown kept left-to-right inside any language. */
function InTime({ label, countdown }: { label: string; countdown: string }) {
    const [before, after = ''] = label.split(MARK);

    return (
        <>
            {before}
            <span dir="ltr" className="font-mono tabular-nums">
                {countdown}
            </span>
            {after}
        </>
    );
}
