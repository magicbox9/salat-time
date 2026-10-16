import type { DayTimes, MosqueSummary } from '@/types/mosque';

/** The five daily prayers the tracker counts (Shuruq is not a prayer). */
export type TrackedPrayer = 'fajr' | 'dhuhr' | 'asr' | 'maghrib' | 'isha';

export const TRACKED_PRAYERS: TrackedPrayer[] = [
    'fajr',
    'dhuhr',
    'asr',
    'maghrib',
    'isha',
];

export type LogStatus = 'on_time' | 'late' | 'qada' | 'missed';

export const STATUSES: LogStatus[] = ['on_time', 'late', 'qada', 'missed'];

export type LogPlace = 'mosque' | 'home' | 'work' | 'other';

export const PLACES: LogPlace[] = ['mosque', 'home', 'work', 'other'];

export type HasanatBreakdown = {
    base: number;
    mosque: number;
    congregation: number;
    streak: number;
    khushu: number;
    rakaat: number;
    total: number;
};

/** App\Services\Hasanat\PrayerLogPresenter */
export type PrayerLogData = {
    id: number;
    date: string;
    prayer: TrackedPrayer;
    status: LogStatus;
    place: LogPlace;
    mosque_id: number | null;
    in_congregation: boolean;
    source: 'web' | 'ios' | 'android';
    prayed_at: string | null;
    metrics: Record<string, number | string> | null;
    hasanat: number;
    breakdown: HasanatBreakdown;
    updated_at: string | null;
};

export type TrackerDay = {
    date: string;
    prayers: Record<TrackedPrayer, PrayerLogData | null>;
    hasanat: number;
};

export type MonthDay = {
    date: string;
    prayed: number;
    logged: number;
    hasanat: number;
};

export type TrackerBadge = {
    key: string;
    target: number;
    progress: number;
    earned: boolean;
};

export type TrackerClockData = {
    timezone: string;
    source: 'mosque' | 'device' | 'default';
    now: string;
    today: string;
    editable_from: string;
};

/** The point values shown in "How points are counted" (config/hasanat.php). */
export type HasanatRules = {
    base: Record<LogStatus, number>;
    mosque: number;
    congregation: number;
    congregation_fajr_isha: number;
    streak_per_day: number;
    streak_max_days: number;
    khushu_max: number;
    complete_rakaat: number;
};

export type TrackerPageProps = {
    clock: TrackerClockData;
    mosque: MosqueSummary | null;
    times: { today: DayTimes | null; tomorrow: DayTimes | null } | null;
    today: TrackerDay;
    week: TrackerDay[];
    stats: {
        total_hasanat: number;
        prayers_prayed: number;
        streak: { current: number; best: number };
    };
    badges: TrackerBadge[];
    rules: HasanatRules;
    month: {
        month: string;
        days: MonthDay[];
        previous: string | null;
        next: string | null;
    };
};

/** What the check-in dialog edits. */
export type CheckInTarget = {
    date: string;
    prayer: TrackedPrayer;
    log: PrayerLogData | null;
    suggested: LogStatus;
};
