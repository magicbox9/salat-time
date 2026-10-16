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

/** One published day (App\Services\PrayerTimes\MosqueTimetable::day). */
export type DayTimes = {
    date: string;
    times: Record<PrayerName, string>;
    iqama: Partial<Record<Exclude<PrayerName, 'shuruq'>, string | null>>;
    jumua: string | null;
};

/** GET /mosques/{slug}/times.json */
export type LiveTimes = {
    timezone: string;
    now: string;
    today: DayTimes | null;
    tomorrow: DayTimes | null;
    days: DayTimes[];
};
