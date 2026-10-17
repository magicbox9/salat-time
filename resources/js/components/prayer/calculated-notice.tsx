import { Calculator } from 'lucide-react';
import type { ReactNode } from 'react';
import type { Translate } from '@/lib/i18n';
import { useT } from '@/lib/i18n';
import { cn } from '@/lib/utils';
import type { CalculationMethod, DayTimes } from '@/types/mosque';

/** True when a day's times were calculated for the place (the mosque publishes none). */
export function isCalculated(day: Pick<DayTimes, 'source'> | null | undefined) {
    return day?.source === 'calculated';
}

/** "the usual convention of mosques in département 69", "the Muslim World League method", … */
export function methodPhrase(
    t: Translate,
    method: CalculationMethod | undefined,
) {
    switch (method?.id) {
        case 'fr-dept':
            return t('site.calculated_method_departement', {
                code: method.departement ?? '',
            });
        case 'fr-national':
            return t('site.calculated_method_national');
        case 'uoif-safety':
            return t('site.calculated_method_uoif');
        case 'mwl':
            return t('site.calculated_method_mwl');
        default:
            return t('site.calculated_method_other');
    }
}

type Props = {
    /** The mosque that publishes no timetable. */
    name: string;
    method?: CalculationMethod;
    className?: string;
    /** Extra content under the explanation (e.g. nearby mosques that publish their times). */
    children?: ReactNode;
};

/**
 * Says plainly that the times shown are calculated, not the mosque's own:
 * which convention, and that Fajr and Isha may differ from the mosque.
 */
export function CalculatedNotice({ name, method, className, children }: Props) {
    const t = useT();

    return (
        <section
            aria-labelledby="calculated-times"
            className={cn(
                'rounded-2xl border border-gold/40 bg-gold/5 p-4 sm:p-5',
                className,
            )}
        >
            <div className="flex items-start gap-3">
                <span className="rounded-xl bg-gold/15 p-2" aria-hidden>
                    <Calculator className="size-5 text-gold" />
                </span>
                <div className="min-w-0">
                    <h2
                        id="calculated-times"
                        className="text-base font-semibold"
                    >
                        {t('site.calculated_title')}
                    </h2>
                    <p className="mt-1 text-sm text-muted-foreground">
                        {t('site.calculated_body', {
                            name,
                            method: methodPhrase(t, method),
                        })}
                    </p>
                </div>
            </div>
            {children}
        </section>
    );
}

/** A small "Calculated" tag for compact places (cards, list rows, the TV screen). */
export function CalculatedTag({ className }: { className?: string }) {
    const t = useT();

    return (
        <span
            title={t('site.calculated_hint')}
            className={cn(
                'inline-flex shrink-0 items-center gap-1 rounded-full border border-gold/50 px-1.5 py-px text-[11px] leading-4 font-medium text-gold',
                className,
            )}
        >
            <Calculator className="size-3" aria-hidden />
            {t('site.calculated')}
        </span>
    );
}
