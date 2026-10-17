<?php

namespace App\Services\PrayerTimes\Calculation;

use DateTimeImmutable;
use DateTimeZone;

/**
 * UTC offsets as the method needs them (SPEC §2.2 and §3): the offset in force
 * at 12:00 local time of a date, which makes daylight-saving change days come
 * out right, and whether a date is a summer-time day.
 */
final class TimeZoneClock
{
    /** @var array<string, DateTimeZone> */
    private static array $zones = [];

    /** @var array<string, float> smallest local-noon offset of a zone's calendar year */
    private static array $standard = [];

    public static function offsetAtLocalNoon(string $timezone, int $y, int $m, int $d): float
    {
        $zone = self::$zones[$timezone] ??= new DateTimeZone($timezone);
        $noon = new DateTimeImmutable(sprintf('%04d-%02d-%02d 12:00:00', $y, $m, $d), $zone);

        return $noon->getOffset() / 3600;
    }

    /** A DST day: the local-noon offset is above the smallest local-noon offset of that year. */
    public static function isDstDay(string $timezone, int $y, int $m, int $d): bool
    {
        $key = $timezone.'|'.$y;
        if (! isset(self::$standard[$key])) {
            $smallest = INF;
            $day = new DateTimeImmutable(sprintf('%04d-01-01', $y));
            while ((int) $day->format('Y') === $y) {
                $smallest = min($smallest, self::offsetAtLocalNoon(
                    $timezone, $y, (int) $day->format('n'), (int) $day->format('j'),
                ));
                $day = $day->modify('+1 day');
            }
            self::$standard[$key] = $smallest;
        }

        return self::offsetAtLocalNoon($timezone, $y, $m, $d) > self::$standard[$key];
    }
}
