import type { DayTimes, MosqueSummary } from '@/types/mosque';

/** Mirrors config/display.php (the server validates the same lists). */
export const THEMES = ['classic', 'night_sky', 'arabesque', 'minimal'] as const;
export const ORIENTATIONS = ['auto', 'landscape', 'portrait'] as const;
export const LANGUAGES = ['ar', 'fr', 'en'] as const;
export const ROTATION_SOURCES = [
    'messages',
    'quran',
    'adhkar',
    'posts',
    'campaigns',
] as const;
export const ADHAN_MODES = ['sound', 'visual', 'off'] as const;
export const CLOCKS = ['24h', '12h'] as const;
export const SCREEN_PRAYERS = [
    'fajr',
    'dhuhr',
    'asr',
    'maghrib',
    'isha',
    'jumua',
] as const;

export type ThemeName = (typeof THEMES)[number];
export type Orientation = (typeof ORIENTATIONS)[number];
export type DisplayLanguage = (typeof LANGUAGES)[number];
export type RotationSource = (typeof ROTATION_SOURCES)[number];
export type AdhanMode = (typeof ADHAN_MODES)[number];
export type ClockStyle = (typeof CLOCKS)[number];
/** The five prayers, with Friday's Dhuhr as Jumu'a. */
export type ScreenPrayer = (typeof SCREEN_PRAYERS)[number];

export type DisplaySettings = {
    theme: ThemeName;
    orientation: Orientation;
    accent_color: string | null;
    languages: DisplayLanguage[];
    clock: ClockStyle;
    show_seconds: boolean;
    show_iqama: boolean;
    show_shuruq: boolean;
    show_jumua: boolean;
    show_hijri: boolean;
    hijri_adjust: number;
    approaching_minutes: number;
    adhan_minutes: number;
    iqama_seconds: number;
    blackout_minutes: Record<ScreenPrayer, number>;
    after_adhkar: boolean;
    after_adhkar_minutes: number;
    rotation: RotationSource[];
    rotation_seconds: number;
    adhan_mode: AdhanMode;
    adhan_id: string | null;
    fajr_adhan_id: string | null;
    volume: number;
    /** Personal screens only. */
    muted?: boolean;
    night_dim: boolean;
    night_from: string;
    night_to: string;
};

export type Ranges = Record<
    | 'hijri_adjust'
    | 'approaching_minutes'
    | 'adhan_minutes'
    | 'iqama_seconds'
    | 'blackout_minutes'
    | 'after_adhkar_minutes'
    | 'rotation_seconds'
    | 'volume',
    [number, number]
>;

/** GET /adhan/catalog.json item. */
export type AdhanTrack = { id: string; name: string; url: string };

export type Verse = {
    key: string;
    surah: number;
    surah_name_ar: string;
    surah_name_en: string;
    /** Verbatim KFGQPC text (with its terminal ayah mark). */
    ayat: { ayah: number; text: string }[];
    translations: Partial<
        Record<
            'en' | 'fr',
            { text: string; title: string; version: string; source_url: string }
        >
    >;
};

export type Dhikr = {
    id: string;
    arabic: string;
    virtue: string | null;
    source: string | null;
    count: number;
    when: ('morning' | 'evening')[];
};

export type AfterPrayerDhikr = {
    id: string;
    arabic: string;
    count: number;
    meaning_en: string | null;
};

export type ScreenPost = {
    id: number;
    type: string;
    title: string;
    excerpt: string;
    published_at: string | null;
};

export type ScreenMessage = {
    id: number;
    body: string;
    ends_at: string | null;
};

export type Labels = Record<string, string>;

/** GET /mosques/{slug}/display.json */
export type DisplayPayload = {
    version: number;
    /** Changes whenever the screen's data changes (GET /mosques/{slug}/display/stamp.json). */
    stamp?: string;
    generated_at: string;
    mosque: MosqueSummary & {
        tagline: string | null;
        accent_color: string | null;
    };
    timezone: string;
    today: string;
    yesterday: DayTimes | null;
    days: DayTimes[];
    jumua: { times: string[]; as_dhuhr: boolean };
    settings: DisplaySettings;
    background_url: string | null;
    catalog: AdhanTrack[];
    messages: ScreenMessage[];
    rotation: {
        verses: Verse[];
        adhkar: Dhikr[];
        after_prayer: AfterPrayerDhikr[];
        posts: ScreenPost[];
    };
    labels: Partial<Record<DisplayLanguage, Labels>>;
};

/** A campaign as GET /mosques/{slug}/campaigns.json describes it (read loosely). */
export type ScreenCampaign = {
    title: string;
    raised: number;
    goal: number | null;
    currency: string;
};

/** What the settings pages offer (App\Http\Controllers\Display\Support\DisplayOptions). */
export type DisplayOptions = {
    themes: ThemeName[];
    orientations: Orientation[];
    languages: DisplayLanguage[];
    rotation_sources: RotationSource[];
    adhan_modes: AdhanMode[];
    clocks: ClockStyle[];
    ranges: Ranges;
    prayers: ScreenPrayer[];
    keys: (keyof DisplaySettings)[];
    defaults: DisplaySettings;
    max_messages: number;
    max_background_kb: number;
    max_adhan_kb: number;
};

/** A phase the preview can play on demand. */
export type SimulatedPhase =
    | 'approaching'
    | 'adhan'
    | 'iqama_countdown'
    | 'iqama'
    | 'prayer'
    | 'after_adhkar';

export type Simulation = { phase: SimulatedPhase; startedAt: number };
