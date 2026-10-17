import { useT } from '@/lib/i18n';
import { cn } from '@/lib/utils';
import { barWidth } from './format';

type Props = {
    percent: number;
    /** Pledged bank transfers, shown as a lighter stretch after the raised part. */
    pledgedPercent?: number;
    size?: 'sm' | 'lg';
    className?: string;
    label?: string;
};

/**
 * Raised (deep green into gold) and pledged (striped gold) shares of the
 * goal. Grows from the leading edge, so it follows the reading direction.
 */
export function ProgressBar({
    percent,
    pledgedPercent = 0,
    size = 'sm',
    className,
    label,
}: Props) {
    const t = useT();
    const raised = barWidth(percent);
    const pledged = Math.max(0, Math.min(100 - raised, pledgedPercent));

    return (
        <div
            role="progressbar"
            aria-valuemin={0}
            aria-valuemax={100}
            aria-valuenow={Math.round(raised)}
            aria-label={label ?? t('fundraising.progress_label')}
            className={cn(
                'relative flex overflow-hidden rounded-full bg-muted ring-1 ring-black/5 ring-inset dark:ring-white/5',
                size === 'lg' ? 'h-3.5' : 'h-2',
                className,
            )}
        >
            <div
                className="h-full rounded-full bg-gradient-to-r from-primary via-emerald-500 to-gold transition-[width] duration-1000 ease-out motion-reduce:transition-none rtl:bg-gradient-to-l"
                style={{ width: `${raised}%` }}
            />
            {pledged > 0 && (
                <div
                    className="h-full bg-[repeating-linear-gradient(135deg,var(--gold)_0_6px,transparent_6px_10px)] opacity-60 transition-[width] duration-1000 ease-out motion-reduce:transition-none"
                    style={{ width: `${pledged}%` }}
                    title={t('fundraising.pledged_hint')}
                />
            )}
        </div>
    );
}
