import { intlLocale } from '@/lib/i18n';

/**
 * Countries offered in the search card (France first). The server geocodes
 * any ISO country code: the French address base for France and its overseas
 * departments, OpenStreetMap's Nominatim for the rest.
 */
export const COUNTRIES = [
    'FR',
    'BE',
    'CH',
    'LU',
    'DE',
    'NL',
    'GB',
    'ES',
    'IT',
    'RE',
    'YT',
    'GP',
    'MQ',
    'GF',
    'MA',
    'DZ',
    'TN',
    'SN',
    'ML',
    'CI',
    'EG',
    'TR',
    'SA',
    'AE',
    'QA',
    'PK',
    'ID',
    'MY',
    'US',
    'CA',
] as const;

/** Countries whose address search can answer as you type (the French BAN). */
const LIVE = new Set(['FR', 'GP', 'MQ', 'GF', 'RE', 'YT', 'PM', 'BL', 'MF']);

/**
 * OpenStreetMap's Nominatim forbids search-as-you-type: elsewhere places are
 * looked up when the visitor presses Enter.
 */
export function searchesAsYouType(country: string): boolean {
    return LIVE.has(country);
}

const namers = new Map<string, Intl.DisplayNames | null>();

/** Country name in the interface language (Intl), falling back to the code. */
export function countryName(code: string, locale: string): string {
    if (!namers.has(locale)) {
        try {
            namers.set(
                locale,
                new Intl.DisplayNames([intlLocale(locale)], { type: 'region' }),
            );
        } catch {
            namers.set(locale, null);
        }
    }

    return namers.get(locale)?.of(code) ?? code;
}

/** "FR" → 🇫🇷 */
export function countryFlag(code: string): string {
    return String.fromCodePoint(
        ...code
            .toUpperCase()
            .split('')
            .map((c) => 0x1f1e6 + c.charCodeAt(0) - 65),
    );
}

/** France first, then the others sorted by their name in the interface language. */
export function sortedCountries(
    locale: string,
): { code: string; name: string }[] {
    const collator = new Intl.Collator(intlLocale(locale));
    const [first, ...rest] = COUNTRIES.map((code) => ({
        code,
        name: countryName(code, locale),
    }));

    return [first, ...rest.sort((a, b) => collator.compare(a.name, b.name))];
}
