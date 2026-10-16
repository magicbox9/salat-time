import { usePage } from '@inertiajs/react';
import { intlLocale } from '@/lib/i18n';

type Style = 'date' | 'datetime';

/** Formats an ISO date in the interface language ("12 Oct 2026", "12 Oct 2026, 14:05"). */
export function useFormatDate(): (
    iso: string | null | undefined,
    style?: Style,
) => string {
    const { locale } = usePage().props;
    const tag = intlLocale(locale);

    return (iso, style = 'date') => {
        if (!iso) {
            return '—';
        }

        const date = new Date(iso);

        if (Number.isNaN(date.getTime())) {
            return '—';
        }

        return new Intl.DateTimeFormat(tag, {
            dateStyle: 'medium',
            ...(style === 'datetime' ? { timeStyle: 'short' } : {}),
        }).format(date);
    };
}
