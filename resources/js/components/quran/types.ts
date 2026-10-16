import type { Translate } from '@/lib/i18n';

export type SurahMeta = {
    number: number;
    name_ar: string;
    /** Transliterated name, e.g. "Al-Fātiḥah". */
    name_en: string;
    ayah_count: number;
    juz: number;
    page: number;
    end_page: number;
};

/** One ayah exactly as published (text ends with the KFGQPC ayah mark). */
export type Ayah = {
    ayah: number;
    text: string;
    juz: number;
    page: number;
};

export type TranslationOption = {
    code: string;
    title: string;
    translator: string;
    version: string;
    language: string;
    source_url: string;
};

export type Translation = TranslationOption & {
    direction: 'ltr' | 'rtl';
    ayat: Record<string, { text: string; notes: string | null }>;
};

export type Reciter = { id: string; name_ar: string; name: string };

export type ReaderBookmark = { id: number; ayah: number; note: string | null };

export type IndexBookmark = ReaderBookmark & {
    surah: number;
    updated_at: string | null;
    name_en: string;
    name_ar: string;
};

/**
 * Count phrases with Arabic plural forms: keys `{prefix}_one`, `_two`,
 * `_few` and `_many` exist in every language file. As in CLDR, "few" is
 * any number ending in 3–10 (7, 109, 206 → آيات); everything else above
 * two takes the singular noun of "many" (11, 100, 286 → آية).
 */
export function pluralForm(count: number): 'one' | 'two' | 'few' | 'many' {
    if (count === 1) {
        return 'one';
    }

    if (count === 2) {
        return 'two';
    }

    const rest = count % 100;

    return rest >= 3 && rest <= 10 ? 'few' : 'many';
}

export function countLabel(
    t: Translate,
    prefix: string,
    count: number,
): string {
    return t(`${prefix}_${pluralForm(count)}`, { count });
}

/** The surah name for the interface language: Arabic in Arabic, else transliterated. */
export function surahName(
    surah: Pick<SurahMeta, 'name_ar' | 'name_en'>,
    locale: string,
): string {
    return locale === 'ar' ? surah.name_ar : surah.name_en;
}

/** A character class from code points (kept as numbers so tools never rewrite them). */
function charClass(...ranges: [number, number?][]): RegExp {
    const body = ranges
        .map(([from, to]) =>
            to === undefined
                ? String.fromCharCode(from)
                : `${String.fromCharCode(from)}-${String.fromCharCode(to)}`,
        )
        .join('');

    return new RegExp(`[${body}]`, 'g');
}

/** KFGQPC ayah-mark glyphs (presentation-form code points). */
const AYAH_MARKS = charClass([0xfc00, 0xfdff]);
const LATIN_ACCENTS = charClass([0x0300, 0x036f]);
/** Harakat, Qur'anic annotation signs, dagger alef and tatweel. */
const ARABIC_MARKS = charClass(
    [0x064b, 0x065f],
    [0x0670],
    [0x06d6, 0x06ed],
    [0x0640],
);
/** Alef with hamza / madda / wasla. */
const ALEF_FORMS = charClass([0x0622, 0x0623], [0x0625], [0x0671]);
/** Apostrophes, ʿayn / hamza signs and hyphens in transliterations. */
const NAME_PUNCTUATION = charClass(
    [0x0027],
    [0x2019],
    [0x02be, 0x02bf],
    [0x0060],
    [0x002d],
);

/** The ayah text without the KFGQPC marker glyph, for copying (as the Mac app does). */
export function plainAyahText(text: string): string {
    return text.replace(AYAH_MARKS, '').trim();
}

/** Lower-case, accent-free, harakat-free text for the surah search. */
export function normalizeSearch(value: string): string {
    return value
        .normalize('NFD')
        .replace(LATIN_ACCENTS, '')
        .replace(ARABIC_MARKS, '')
        .replace(ALEF_FORMS, String.fromCharCode(0x0627))
        .replace(NAME_PUNCTUATION, '')
        .replace(/\s+/g, ' ')
        .toLowerCase()
        .trim();
}

/** Small localStorage helpers that never throw (private mode, quotas). */
export function readStored(key: string): string | null {
    try {
        return window.localStorage.getItem(key);
    } catch {
        return null;
    }
}

export function writeStored(key: string, value: string): void {
    try {
        window.localStorage.setItem(key, value);
    } catch {
        // Storage is a convenience only.
    }
}
