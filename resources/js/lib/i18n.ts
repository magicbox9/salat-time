import { usePage } from '@inertiajs/react';

export type Translate = (
    key: string,
    replace?: Record<string, string | number>,
) => string;

/**
 * Interface strings shared by the server (lang/{locale}/{group}.json).
 * Keys look like "site.nav_quran"; {name} placeholders are replaced.
 */
export function useT(): Translate {
    const { ui } = usePage().props;

    return (key, replace) => {
        let text = ui[key] ?? key;

        if (replace) {
            for (const [name, value] of Object.entries(replace)) {
                text = text.replaceAll(`{${name}}`, String(value));
            }
        }

        return text;
    };
}

/** BCP 47 tag for Intl formatting (Arabic digits stay Western for times). */
export function intlLocale(locale: string): string {
    return locale === 'ar' ? 'ar-u-nu-latn' : locale;
}
