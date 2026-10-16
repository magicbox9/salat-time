import { usePage } from '@inertiajs/react';
import { intlLocale } from '@/lib/i18n';

/** Formats counts with the interface language's grouping (3,585 · 3 585). */
export function useFormatNumber(): (value: number) => string {
    const { locale } = usePage().props;
    const format = new Intl.NumberFormat(intlLocale(locale));

    return (value) => format.format(value);
}
