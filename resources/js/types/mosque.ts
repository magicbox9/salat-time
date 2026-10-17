export type PrayerName =
    | 'fajr'
    | 'shuruq'
    | 'dhuhr'
    | 'asr'
    | 'maghrib'
    | 'isha';

export const PRAYERS: PrayerName[] = [
    'fajr',
    'shuruq',
    'dhuhr',
    'asr',
    'maghrib',
    'isha',
];

/** The fields every page and map can rely on (App\Support\MosquePresenter). */
export type MosqueSummary = {
    id: number;
    slug: string;
    name: string;
    address: string | null;
    postcode: string | null;
    city: string | null;
    country_code: string;
    lat: number;
    lng: number;
    timezone: string;
    distance_m: number | null;
    has_times: boolean;
    verified: boolean;
    source: 'mawaqit' | 'directory' | 'osm' | 'manual';
    logo_url: string | null;
    mawaqit_url: string | null;
    google_maps_url: string;
};

/** Where a day's times come from: the mosque's own calendar, or calculated for its place. */
export type TimesSource = 'published' | 'calculated';

/** The calculation behind a calculated day (App\Services\PrayerTimes\CalculatedTimes). */
export type CalculationMethod = {
    /** "fr-dept" (département table), "fr-national", "uoif-safety", "mwl", … */
    id: string;
    departement: string | null;
    /** The method data's identity, e.g. "fr-dept-2026.1". */
    version: string;
};

/** One day of times (App\Services\PrayerTimes\MosqueTimetable::day). */
export type DayTimes = {
    date: string;
    times: Record<PrayerName, string>;
    iqama: Partial<Record<Exclude<PrayerName, 'shuruq'>, string | null>>;
    jumua: string | null;
    source?: TimesSource;
    method?: CalculationMethod;
};

/** GET /mosques/{slug}/times.json */
export type LiveTimes = {
    timezone: string;
    now: string;
    today: DayTimes | null;
    tomorrow: DayTimes | null;
    days: DayTimes[];
};
