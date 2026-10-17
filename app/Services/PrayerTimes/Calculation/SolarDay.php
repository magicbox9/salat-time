<?php

namespace App\Services\PrayerTimes\Calculation;

/**
 * One civil date at one place: the solar events the prayer specs need, in
 * float local hours (SPEC §2, the Mawaqit arithmetic). Nothing carries over
 * from one day to the next.
 */
final class SolarDay
{
    private const SLOTS = [5, 6, 12, 13, 18];

    public readonly float $offset;

    public readonly float $shift;

    public readonly int $jdn;

    /** 0-based day of the year. */
    public readonly int $doy0;

    /** @var array<int, float> declination at each guess slot */
    private array $decl = [];

    /** @var array<int, float> solar noon at each guess slot */
    private array $noon = [];

    /** @param  float|null  $utcOffsetHours  by default the zone's offset at local noon */
    public function __construct(
        public readonly int $year,
        public readonly int $month,
        public readonly int $day,
        public readonly float $latitude,
        public readonly float $longitude,
        public readonly string $timezone,
        ?float $utcOffsetHours = null,
    ) {
        $jdBase = Astro::julianDate($year, $month, $day) - $longitude / (15 * 24);
        $this->offset = $utcOffsetHours ?? TimeZoneClock::offsetAtLocalNoon($timezone, $year, $month, $day);
        $this->shift = $this->offset - $longitude / 15;
        foreach (self::SLOTS as $slot) {
            [$decl, $eqt] = Astro::sun($jdBase + $slot / 24);
            $this->decl[$slot] = $decl;
            $this->noon[$slot] = Astro::fix(12 - $eqt, 24);
        }
        $this->jdn = Astro::gregorianToJdn($year, $month, $day);
        $this->doy0 = (int) gmdate('z', gmmktime(0, 0, 0, $month, $day, $year));
    }

    /** Hours between solar noon and the moment the sun is $angle degrees below the horizon. */
    public function hourAngle(float $angle, int $slot, float $lat): float
    {
        $sl = sin(Astro::rad($lat));
        $cl = cos(Astro::rad($lat));
        $sd = sin(Astro::rad($this->decl[$slot]));
        $cd = cos(Astro::rad($this->decl[$slot]));
        $p1 = -sin(Astro::rad($angle)) - $sd * $sl;
        $p2 = $cd * $cl;
        // Clamped: an angle the sun never reaches gives solar midnight, never NaN.
        $cr = min(1.0, max(-1.0, $p1 / $p2));

        return 1 / 15 * Astro::deg(acos($cr));
    }

    public function before(float $angle, int $slot, float $lat): float
    {
        return ($this->noon[$slot] - $this->hourAngle($angle, $slot, $lat)) + $this->shift;
    }

    public function after(float $angle, int $slot, float $lat): float
    {
        return ($this->noon[$slot] + $this->hourAngle($angle, $slot, $lat)) + $this->shift;
    }

    public function sunrise(?float $lat = null): float
    {
        return $this->before(0.833, 6, $lat ?? $this->latitude);
    }

    public function sunset(?float $lat = null): float
    {
        return $this->after(0.833, 18, $lat ?? $this->latitude);
    }

    public function transit(): float
    {
        return $this->noon[12] + $this->shift;
    }

    /** Asr for a shadow factor (1 Shafi'i/Maliki, 2 Hanafi) and Mawaqit's server clock (SPEC §2.6). */
    public function asr(float $factor, float $clock, ?string $epoch, float $lat): float
    {
        $adecl = $epoch === 'praytimes'
            ? $this->decl[13]
            : Astro::sun(($this->jdn + Astro::clockFraction($clock)) + 13 / 24)[0];
        $x = abs($lat - $adecl);
        $angle = -((atan(1 / ($factor + tan(Astro::rad($x)))) * 180.0) / M_PI);

        return ($this->noon[13] + $this->hourAngle($angle, 13, $lat)) + $this->shift;
    }

    /**
     * Fajr ('fajr', before sunrise) or Isha-type ('isha', after sunset)
     * twilight, bounded by a high-latitude rule (SPEC §2.5).
     */
    public function twilight(string $prayer, float $angle, string $rule, float $lat, ?float $nightFraction = null): float
    {
        $t = $prayer === 'fajr' ? $this->before($angle, 5, $lat) : $this->after($angle, 18, $lat);
        if ($rule === 'NONE') {
            return $t;
        }
        $rise = $this->sunrise($lat);
        $set = $this->sunset($lat);
        $night = Astro::fix($rise - $set, 24);
        $portion = match ($rule) {
            'ANGLE_BASED' => 1 / 60 * $angle * $night,
            'ONE_SEVENTH' => 1 / 7 * $night,
            'MIDDLE_OF_THE_NIGHT' => 1 / 2 * $night,
            'NIGHT_FRACTION' => $nightFraction !== null
                ? $nightFraction * $night
                : throw new UnknownSpec('NIGHT_FRACTION needs night_fraction'),
            default => throw new UnknownSpec("unknown rule {$rule}"),
        };
        if ($prayer === 'fajr') {
            return (is_nan($t) || Astro::fix($rise - $t, 24) > $portion) ? $rise - $portion : $t;
        }

        return (is_nan($t) || Astro::fix($t - $set, 24) > $portion) ? $set + $portion : $t;
    }
}
