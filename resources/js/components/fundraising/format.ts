import { usePage } from '@inertiajs/react';
import { intlLocale } from '@/lib/i18n';

export type MoneyFormat = (cents: number, currency?: string) => string;

/**
 * Amounts are integer cents on the server. "1 250 €" (no decimals when the
 * amount is whole), "12,50 €" otherwise — in the interface language, with
 * Western digits in Arabic.
 */
export function useMoney(): MoneyFormat {
    const { locale } = usePage().props;
    const tag = intlLocale(locale);

    return (cents, currency = 'EUR') => {
        const whole = cents % 100 === 0;

        return new Intl.NumberFormat(tag, {
            style: 'currency',
            currency,
            minimumFractionDigits: whole ? 0 : 2,
            maximumFractionDigits: whole ? 0 : 2,
        }).format(cents / 100);
    };
}

/** Plain grouped numbers (donors, days). */
export function useCount(): (value: number) => string {
    const { locale } = usePage().props;
    const format = new Intl.NumberFormat(intlLocale(locale));

    return (value) => format.format(value);
}

/** "12,5" — a share of the goal, one decimal at most. */
export function usePercent(): (value: number) => string {
    const { locale } = usePage().props;
    const format = new Intl.NumberFormat(intlLocale(locale), {
        maximumFractionDigits: 1,
    });

    return (value) => format.format(value);
}

/** "3 min ago", "2 days ago" in the interface language. */
export function useTimeAgo(): (iso: string | null) => string {
    const { locale } = usePage().props;
    const format = new Intl.RelativeTimeFormat(intlLocale(locale), {
        numeric: 'auto',
    });

    return (iso) => {
        if (!iso) {
            return '';
        }

        const seconds = (new Date(iso).getTime() - Date.now()) / 1000;
        const steps: [Intl.RelativeTimeFormatUnit, number][] = [
            ['year', 31_536_000],
            ['month', 2_592_000],
            ['week', 604_800],
            ['day', 86_400],
            ['hour', 3_600],
            ['minute', 60],
        ];

        for (const [unit, size] of steps) {
            if (Math.abs(seconds) >= size) {
                return format.format(Math.round(seconds / size), unit);
            }
        }

        return format.format(0, 'minute');
    };
}

/** Euros typed by a donor ("25", "25,50", "25.5") → cents, or null. */
export function parseEuros(input: string): number | null {
    const clean = input.replace(/\s/g, '').replace(',', '.');

    if (!/^\d{1,7}(\.\d{0,2})?$/.test(clean)) {
        return null;
    }

    return Math.round(Number.parseFloat(clean) * 100);
}

/** The progress bar never overflows; the figure beside it may pass 100 %. */
export function barWidth(percent: number): number {
    return Math.max(0, Math.min(100, percent));
}

export function prefersReducedMotion(): boolean {
    return (
        typeof window !== 'undefined' &&
        window.matchMedia?.('(prefers-reduced-motion: reduce)').matches
    );
}
