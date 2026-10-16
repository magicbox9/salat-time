import type { Translate } from '@/lib/i18n';
import { intlLocale } from '@/lib/i18n';

/** 840 → "840 m", 2350 → "2.4 km" (localised decimal separator); nothing under 5 m. */
export function formatDistance(
    meters: number | null | undefined,
    t: Translate,
    locale: string,
): string | null {
    // Unknown, or the search point is the mosque itself.
    if (meters === null || meters === undefined || meters < 5) {
        return null;
    }

    if (meters < 1000) {
        return t('site.m_away', {
            distance: Math.max(10, Math.round(meters / 10) * 10),
        });
    }

    const km = new Intl.NumberFormat(intlLocale(locale), {
        maximumFractionDigits: meters < 10000 ? 1 : 0,
    }).format(meters / 1000);

    return t('site.km_away', { distance: km });
}

/** Directions link (same format as the server's google_maps_url). */
export function mapsUrl(pin: {
    lat: number;
    lng: number;
    google_maps_url?: string;
}): string {
    return (
        pin.google_maps_url ??
        `https://www.google.com/maps/search/?api=1&query=${pin.lat},${pin.lng}`
    );
}

/** "YYYY-MM-DD" of an instant in a time zone ("" if the zone is unknown). */
export function dateInZone(timeZone: string, at: Date): string {
    try {
        const parts = new Intl.DateTimeFormat('en-GB', {
            timeZone,
            year: 'numeric',
            month: '2-digit',
            day: '2-digit',
        }).formatToParts(at);
        const get = (type: string) =>
            parts.find((part) => part.type === type)?.value ?? '';

        return `${get('year')}-${get('month')}-${get('day')}`;
    } catch {
        return '';
    }
}

/**
 * The published days that apply now. Cards hold the days that were "today"
 * and "tomorrow" when they were fetched: once the mosque's midnight passes,
 * tomorrow's row becomes today's, and rows left days behind show nothing
 * (never a past day's times).
 */
export function currentDays<T extends { date: string }>(
    today: T | null,
    tomorrow: T | null,
    date: string,
): [T | null, T | null] {
    if (tomorrow && date === tomorrow.date) {
        return [tomorrow, null];
    }

    const last = tomorrow?.date ?? today?.date;

    if (date && last && date > last) {
        return [null, null];
    }

    return [today, tomorrow];
}

/** Great-circle distance in metres. */
export function metersBetween(
    a: { lat: number; lng: number },
    b: { lat: number; lng: number },
): number {
    const rad = Math.PI / 180;
    const h =
        Math.sin(((b.lat - a.lat) * rad) / 2) ** 2 +
        Math.cos(a.lat * rad) *
            Math.cos(b.lat * rad) *
            Math.sin(((b.lng - a.lng) * rad) / 2) ** 2;

    return 2 * 6371000 * Math.asin(Math.min(1, Math.sqrt(h)));
}

/** "12 rue X, 75011 Paris" without repeating a postcode or city the address already holds. */
export function placeLine(mosque: {
    address?: string | null;
    postcode?: string | null;
    city?: string | null;
}): string {
    const address = mosque.address?.trim() ?? '';
    const lower = address.toLowerCase();
    const locality = [mosque.postcode, mosque.city]
        .filter(
            (part): part is string =>
                Boolean(part) && !lower.includes(String(part).toLowerCase()),
        )
        .join(' ');

    return [address, locality].filter(Boolean).join(', ');
}
