<?php

namespace App\Http\Controllers\Hub\Support;

/**
 * A published day (MosqueTimetable::day) made safe for the hub's clocks.
 *
 * Imported calendars hold a few rows that are not clock times: empty cells,
 * "ERROR", "18h30", "20:00:00". The same value written another way
 * ("18h30" → "18:30") is kept; a day missing any of its six times is not
 * shown at all (the hub then says it has no published times for today and
 * never fills a gap with a guess).
 */
final class PublishedDay
{
    private const CLOCK = '/^(\d{1,2})\s*[:hH]\s*(\d{2})(?::\d{2})?$/';

    /**
     * @param  array<string, mixed>|null  $day  MosqueTimetable::day()
     * @return array<string, mixed>|null
     */
    public static function clean(?array $day): ?array
    {
        if ($day === null || ! is_array($day['times'] ?? null) || count($day['times']) !== 6) {
            return null;
        }

        $times = [];
        foreach ($day['times'] as $prayer => $value) {
            $time = self::clock($value);
            if ($time === null) {
                return null;
            }
            $times[$prayer] = $time;
        }

        $jumua = is_string($day['jumua'] ?? null) ? trim($day['jumua']) : '';

        return [
            ...$day,
            'times' => $times,
            'iqama' => array_map(fn ($value) => self::clock($value), is_array($day['iqama'] ?? null) ? $day['iqama'] : []),
            // A mosque's own wording ("13h30") is kept when it is not a plain time.
            'jumua' => $jumua === '' ? null : (self::clock($jumua) ?? $jumua),
        ];
    }

    /** "6:05", "06h05", "06:05:00" → "06:05"; anything else → null. */
    public static function clock(mixed $value): ?string
    {
        if (! is_string($value) || ! preg_match(self::CLOCK, trim($value), $m)) {
            return null;
        }

        $hour = (int) $m[1];
        $minute = (int) $m[2];

        return $hour < 24 && $minute < 60 ? sprintf('%02d:%02d', $hour, $minute) : null;
    }
}
