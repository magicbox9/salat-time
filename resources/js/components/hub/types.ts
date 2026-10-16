import type { MosqueCard } from '@/components/discover/types';
import type {
    DayTimes,
    LiveTimes,
    MosqueSummary,
    PrayerName,
} from '@/types/mosque';

export type HubStyle = 'cards' | 'timeline' | 'arc' | 'dial' | 'minimal';

export const HUB_STYLES: HubStyle[] = [
    'cards',
    'timeline',
    'arc',
    'dial',
    'minimal',
];

export type AdhanMode = 'off' | 'sound' | 'visual';

/** users.preferences.home (App\Http\Controllers\Hub\Support\HubPreferences). */
export type HubPrefs = {
    style: HubStyle;
    show_iqama: boolean;
    show_seconds: boolean;
    clock: '24h' | '12h';
    show_hijri: boolean;
    compact: boolean;
    adhan: AdhanMode;
    adhan_id: string | null;
    muted: boolean;
};

export type HubMosque = MosqueSummary & {
    tagline: string | null;
    accent_color: string | null;
};

export type HubPost = {
    id: number;
    type: 'news' | 'event' | 'announcement' | 'janaza';
    title: string;
    excerpt: string;
    image_url: string | null;
    published_at: string | null;
    category: string | null;
    url: string;
};

export type TrackedPrayer = 'fajr' | 'dhuhr' | 'asr' | 'maghrib' | 'isha';

export type TrackerLogs = Record<
    TrackedPrayer,
    { status: string; hasanat: number } | null
>;

export type HubTracker = {
    date: string;
    timezone: string;
    logs: TrackerLogs;
    /** The day before (an Isha after midnight is checked in on its evening). */
    previous: { date: string; logs: TrackerLogs };
};

export type HubPageProps = {
    mosque: HubMosque;
    chosenBy: 'user' | 'cookie';
    live: Omit<LiveTimes, 'days'> & {
        /** The evening before, only while its Isha falls after midnight. */
        yesterday: DayTimes | null;
    };
    nearbyWithTimes: MosqueCard[];
    posts: HubPost[];
    tracker: HubTracker | null;
    preferences: HubPrefs | null;
    defaults: HubPrefs;
    canManage: boolean;
};

/** GET /adhan/catalog.json (module "display"). */
export type AdhanTrack = { id: string; name: string; url: string };

export type RowState = 'passed' | 'current' | 'next' | 'upcoming';

/** One line of the day, as every display style draws it. */
export type TimeRow = {
    prayer: PrayerName;
    /** Published adhan time ("HH:MM"); tomorrow's for a "next" Fajr after Isha. */
    time: string;
    /** Minutes after today's midnight, increasing (an Isha after midnight is > 1440). */
    minutes: number;
    iqama: string | null;
    /** The iqama in minutes on the same clock as `minutes`. */
    iqamaAt: number | null;
    /** Friday prayer time, shown with Dhuhr. */
    jumua: string | null;
    state: RowState;
    /** The next day's Fajr, shown before the mosque's midnight ("Tomorrow"). */
    tomorrow: boolean;
};

/** Everything a display style needs, computed once per second by the page. */
export type DayView = {
    today: DayTimes;
    rows: TimeRow[];
    /** Minutes since the mosque's midnight (with seconds as a fraction). */
    nowMinutes: number;
    next: TimeRow | null;
    /** Minutes until the next prayer. */
    untilNext: number | null;
    timezone: string;
};
