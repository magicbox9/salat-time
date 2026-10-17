<?php

namespace App\Services\PrayerTimes\Calculation;

/**
 * Turns a prayer "spec" (SPEC §3: the rule for one prayer, as the département
 * table, the standard methods and "Match my mosque" describe it) into a minute
 * after local midnight. Isha after midnight is reported as ≥ 1440 so the six
 * prayers stay in order.
 */
final class SpecEvaluator
{
    /** The engine's prayer names, in order. */
    public const PRAYERS = ['fajr', 'sunrise', 'dhuhr', 'asr', 'maghrib', 'isha'];

    /**
     * The six minutes of one civil date at one place.
     *
     * @param  array<string, array<string, mixed>>  $specs  keyed by self::PRAYERS
     * @param  array<string, int>  $adjustments  whole minutes added last, per prayer
     * @return array<string, int>
     */
    public static function computeDay(
        int $y, int $m, int $d, float $lat, float $lon, string $timezone,
        array $specs, array $adjustments = [], ?float $utcOffsetHours = null,
    ): array {
        $day = new SolarDay($y, $m, $d, $lat, $lon, $timezone, $utcOffsetHours);
        $out = [];
        foreach (self::PRAYERS as $prayer) {
            $out[$prayer] = self::evaluate($day, $prayer, $specs[$prayer] ?? []) + ($adjustments[$prayer] ?? 0);
        }

        return $out;
    }

    /** @param  array<string, mixed>  $spec */
    public static function evaluate(SolarDay $day, string $prayer, array $spec): int
    {
        $family = $spec['family'] ?? null;
        $lat = isset($spec['lat_eff']) ? (float) $spec['lat_eff'] : $day->latitude;
        $offset = (int) ($spec['offset'] ?? 0);

        return match ($prayer) {
            'fajr', 'isha' => self::twilightPrayer($day, $prayer, $spec, $family, $lat, $offset),
            'sunrise' => $family === 'sunrise'
                ? Astro::minuteOf($day->sunrise($lat)) + $offset
                : throw new UnknownSpec("unknown sunrise family {$family}"),
            'maghrib' => match ($family) {
                'sunset' => Astro::minuteOf($day->sunset($lat)) + $offset,
                'angle' => Astro::minuteOf($day->twilight(
                    'isha', (float) $spec['angle'], $spec['rule'] ?? 'ANGLE_BASED', $lat,
                )) + $offset,
                default => throw new UnknownSpec("unknown maghrib family {$family}"),
            },
            'asr' => self::asr($day, $spec, $family, $lat, $offset),
            'dhuhr' => self::dhuhr($day, $spec, $family, $offset),
            default => throw new UnknownSpec("unknown prayer {$prayer}"),
        };
    }

    /** @param  array<string, mixed>  $spec */
    private static function twilightPrayer(SolarDay $day, string $prayer, array $spec, ?string $family, float $lat, int $offset): int
    {
        if ($family === 'interval') {
            $minute = $prayer === 'fajr'
                ? Astro::minuteOf($day->sunrise($lat)) - (int) $spec['minutes']
                : Astro::minuteOf($day->sunset($lat)) + (int) $spec['minutes'];

            return self::clip($minute, $spec);
        }
        [$angle, $rule] = match ($family) {
            'angle' => [(float) $spec['angle'], $spec['rule'] ?? 'ANGLE_BASED'],
            'monthly_angle' => [(float) $spec['angles'][$day->month - 1], $spec['rule'] ?? 'NONE'],
            'seasonal_angle' => [
                $spec['a'] + $spec['b'] * cos(2 * M_PI * ($day->doy0 - 355) / 365.25),
                $spec['rule'] ?? 'ANGLE_BASED',
            ],
            default => throw new UnknownSpec("unknown {$prayer} family {$family}"),
        };
        $nightFraction = isset($spec['night_fraction']) ? (float) $spec['night_fraction'] : null;
        $minute = Astro::minuteOf($day->twilight($prayer, (float) $angle, $rule, $lat, $nightFraction));
        if ($prayer === 'isha' && $minute < 360) {
            $minute += 1440;
        }

        return self::clip($minute + $offset, $spec);
    }

    /** @param  array<string, mixed>  $spec */
    private static function asr(SolarDay $day, array $spec, ?string $family, float $lat, int $offset): int
    {
        if ($family !== 'shadow') {
            throw new UnknownSpec("unknown asr family {$family}");
        }
        $minute = Astro::minuteOf($day->asr(
            (float) ($spec['factor'] ?? 1), (float) ($spec['clock'] ?? 20.0), $spec['epoch'] ?? null, $lat,
        )) + $offset;

        return isset($spec['floor']) ? max($minute, (int) $spec['floor']) : $minute;
    }

    /** @param  array<string, mixed>  $spec */
    private static function dhuhr(SolarDay $day, array $spec, ?string $family, int $offset): int
    {
        $noon = Astro::minuteOf($day->transit());

        return match ($family) {
            'transit' => $noon + $offset,
            'transit_floor' => max($noon + $offset, (int) $spec['floor']),
            'transit_cap' => min($noon + $offset, (int) $spec['cap']),
            'fixed' => (int) $spec['value'],
            'fixed_by_dst' => TimeZoneClock::isDstDay($day->timezone, $day->year, $day->month, $day->day)
                ? (int) $spec['dst'] : (int) $spec['std'],
            'mixed_dst' => self::mixedDst($day, $spec, $noon + $offset),
            default => throw new UnknownSpec("unknown dhuhr family {$family}"),
        };
    }

    /** @param  array<string, mixed>  $spec */
    private static function mixedDst(SolarDay $day, array $spec, int $computed): int
    {
        $dst = TimeZoneClock::isDstDay($day->timezone, $day->year, $day->month, $day->day);
        $calculated = ($spec['calc_in'] ?? null) === 'std' ? ! $dst : $dst;

        return $calculated ? $computed : (int) $spec['value'];
    }

    /** @param  array<string, mixed>  $spec */
    private static function clip(int $minute, array $spec): int
    {
        if (isset($spec['floor'])) {
            $minute = max($minute, (int) $spec['floor']);
        }
        if (isset($spec['cap'])) {
            $minute = min($minute, (int) $spec['cap']);
        }

        return $minute;
    }
}
