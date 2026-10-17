import type {
    DisplayLanguage,
    DisplayPayload,
    DisplaySettings,
    ScreenPrayer,
} from '../types';

export type ScreenText = {
    primary: DisplayLanguage;
    secondary: DisplayLanguage | null;
    /** A label in a language (falls back to English, then to the key). */
    in: (
        language: DisplayLanguage,
        key: string,
        replace?: Record<string, string | number>,
    ) => string;
    /** A label in the main language. */
    t: (key: string, replace?: Record<string, string | number>) => string;
    /** The same label in the second language, or null. */
    t2: (
        key: string,
        replace?: Record<string, string | number>,
    ) => string | null;
    prayer: (prayer: ScreenPrayer | 'shuruq') => {
        main: string;
        second: string | null;
    };
    /** The non-Arabic language a translation of the meanings is shown in. */
    translation: 'en' | 'fr' | null;
};

/**
 * The words on the screen, in the languages the screen shows (its first
 * language large, the second one under it), from the payload's labels.
 */
export function screenText(
    payload: DisplayPayload,
    settings: DisplaySettings,
): ScreenText {
    const languages =
        settings.languages.length > 0
            ? settings.languages
            : (['ar'] as DisplayLanguage[]);
    const primary = languages[0];
    const secondary = languages[1] ?? null;
    const lookup = (
        language: DisplayLanguage,
        key: string,
        replace?: Record<string, string | number>,
    ) => {
        let text =
            payload.labels[language]?.[key] ?? payload.labels.en?.[key] ?? key;

        for (const [name, value] of Object.entries(replace ?? {})) {
            text = text.replaceAll(`{${name}}`, String(value));
        }

        return text;
    };
    const translation =
        (languages.find((l) => l === 'fr' || l === 'en') as
            | 'en'
            | 'fr'
            | undefined) ?? null;

    return {
        primary,
        secondary,
        in: lookup,
        t: (key, replace) => lookup(primary, key, replace),
        t2: (key, replace) =>
            secondary ? lookup(secondary, key, replace) : null,
        prayer: (prayer) => ({
            main: lookup(primary, `prayer_${prayer}`),
            second: secondary ? lookup(secondary, `prayer_${prayer}`) : null,
        }),
        translation,
    };
}

export const isRtl = (language: string) => language === 'ar';
