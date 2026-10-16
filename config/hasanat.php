<?php

/*
|--------------------------------------------------------------------------
| Hasanat — the prayer tracker's points
|--------------------------------------------------------------------------
|
| Points are a gentle encouragement to pray well and on time. They are not a
| measure of anyone's reward: Allah alone knows the true reward. Keep every
| number modest and every rule easy to explain.
|
| A logged prayer earns:
|
|   base[status]                     on time > late > made up (qada) > missed (0)
| + place.mosque                     prayed at a mosque
| + congregation[prayer|default]     prayed in congregation (Fajr and Isha a little more)
| + streak (per prayer)              min(days in a row with all five prayed, max_days) × per_day
| + metrics (phone apps only)        khushu (stillness) and complete rakaat
|
| A missed prayer always earns 0: no bonus applies to it.
|
*/

return [

    // Base points by status (App\Models\PrayerLog::STATUSES).
    'base' => [
        'on_time' => 10,
        'late' => 6,
        'qada' => 4,
        'missed' => 0,
    ],

    // Prayed at a mosque.
    'place' => [
        'mosque' => 5,
    ],

    // Prayed in congregation. Fajr and Isha in congregation count a little more.
    'congregation' => [
        'default' => 5,
        'fajr' => 7,
        'isha' => 7,
    ],

    // Days in a row where all five prayers were prayed (these statuses count).
    // Each prayer of such a day earns per_day × the streak length, capped.
    'streak' => [
        'statuses' => ['on_time', 'late', 'qada'],
        'per_day' => 1,
        'max_days' => 7,
    ],

    // Phone sensors (iOS / Android companion apps). Applied only when present.
    'metrics' => [
        // Stillness 0–1 → khushu bonus, scaled linearly above the threshold.
        'khushu' => [
            'threshold' => 0.2,
            'max' => 5,
        ],
        // Completed rakaat at least the prayer's fard count.
        'complete_rakaat' => 3,
    ],

    // Fard rakaat per prayer (Jumu'a replaces Dhuhr with 2 on Friday at the mosque).
    'fard_rakaat' => [
        'fajr' => 2,
        'dhuhr' => 4,
        'asr' => 4,
        'maghrib' => 3,
        'isha' => 4,
        'jumua' => 2,
    ],

    // Logs can be added or changed for today and this many past days.
    'edit_window_days' => 7,

    // Badges: [kind, target]. Kinds are counted by App\Services\Hasanat\TrackerStats.
    'badges' => [
        'first_prayer' => 1,
        'on_time_100' => 100,
        'fajr_mosque_10' => 10,
        'congregation_40' => 40,
        'streak_7' => 7,
        'streak_30' => 30,
    ],

];
