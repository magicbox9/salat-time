<?php

namespace App\Services\PrayerTimes\Calculation;

/**
 * The arithmetic building blocks of the "France — mosque convention" method
 * (resources/prayer-method/SPEC.md §1–2): Julian days, the sun's position and
 * the minute rounding. Every formula keeps the operation order of the spec,
 * because the results are rounded to the minute and a reordered expression can
 * move a time by one minute.
 */
final class Astro
{
    public static function rad(float $x): float
    {
        return ($x * M_PI) / 180.0;
    }

    public static function deg(float $x): float
    {
        return ($x * 180.0) / M_PI;
    }

    /** $a modulo $b in [0, $b). */
    public static function fix(float $a, float $b): float
    {
        if (is_nan($a)) {
            return $a;
        }
        $a = $a - $b * floor($a / $b);

        return $a < 0 ? $a + $b : $a;
    }

    /** Julian day at 0h UT of a civil date (Meeus). */
    public static function julianDate(int $y, int $m, int $d): float
    {
        if ($m <= 2) {
            $y -= 1;
            $m += 12;
        }
        $a = floor($y / 100);
        $b = 2 - $a + floor($a / 4);

        return floor(365.25 * ($y + 4716)) + floor(30.6001 * ($m + 1)) + $d + $b - 1524.5;
    }

    /** Integer Julian Day Number, used only by the Asr server-clock quirk (2026-01-01 → 2461042). */
    public static function gregorianToJdn(int $y, int $m, int $d): int
    {
        $yy = $y + 4800;
        if ($m > 2) {
            $mm = $m - 3;
        } else {
            $mm = $m + 9;
            $yy -= 1;
        }

        return intdiv(intdiv($yy, 100) * 146097, 4) + intdiv(($yy % 100) * 1461, 4)
            + intdiv($mm * 153 + 2, 5) + $d - 32045;
    }

    /**
     * Sun declination (degrees) and equation of time (hours), from the USNO
     * approximate solar coordinates.
     *
     * @return array{0: float, 1: float}
     */
    public static function sun(float $jd): array
    {
        $d = $jd - 2451545.0;
        $g = self::fix(357.529 + 0.98560028 * $d, 360);
        $q = self::fix(280.459 + 0.98564736 * $d, 360);
        $l = self::fix($q + 1.915 * sin(self::rad($g)) + 0.020 * sin(self::rad(2 * $g)), 360);
        $e = 23.439 - 0.00000036 * $d;
        $ra = self::deg(atan2(cos(self::rad($e)) * sin(self::rad($l)), cos(self::rad($l)))) / 15;
        $eqt = $q / 15 - self::fix($ra, 24);
        $decl = self::deg(asin(sin(self::rad($e)) * sin(self::rad($l))));

        return [$decl, $eqt];
    }

    /** Round half-up to a minute of the day, 0…1439 (PHP getFormattedTime). */
    public static function minuteOf(float $t): int
    {
        $tt = self::fix($t + 0.5 / 60, 24);
        $h = floor($tt);
        $mi = floor(($tt - $h) * 60);

        return (int) ($h * 60 + $mi);
    }

    /** The day fraction of a UTC clock hour, as Mawaqit's server reads it for Asr. */
    public static function clockFraction(float $h): float
    {
        $h = fmod(fmod($h, 24) + 24, 24);
        $whole = floor($h);
        $rem = ($h - $whole) * 60;
        $i = floor($rem + 1e-9);
        $s = min(floor(($rem - $i) * 60 + 1e-6), 59);
        $dayFraction = $whole / 24 - 0.5;
        if ($dayFraction < 0) {
            $dayFraction += 1;
        }

        return $dayFraction + ($i + $s / 60) / 60 / 24;
    }
}
