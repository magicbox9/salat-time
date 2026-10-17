<?php

namespace App\Services\PrayerTimes;

use App\Models\Mosque;
use App\Services\PrayerTimes\Calculation\ConventionTable;
use App\Services\PrayerTimes\Calculation\PlaceConvention;
use App\Services\PrayerTimes\Calculation\SpecEvaluator;
use Carbon\CarbonInterface;

/**
 * Prayer times calculated for a place, for when no mosque calendar is
 * published there: the convention mosques of the place's département usually
 * follow (or a standard method outside metropolitan France). These are never
 * a mosque's own times: they carry no iqama and are marked "calculated".
 */
class CalculatedTimes
{
    /** The app's prayer names, in the engine's order (the engine says "sunrise" for Shuruq). */
    private const NAMES = ['fajr' => 'fajr', 'sunrise' => 'shuruq', 'dhuhr' => 'dhuhr', 'asr' => 'asr', 'maghrib' => 'maghrib', 'isha' => 'isha'];

    /** @var array<int, PlaceConvention> */
    private array $conventions = [];

    public function __construct(private readonly ConventionTable $table) {}

    public function conventionFor(Mosque $mosque): PlaceConvention
    {
        // Metropolitan France runs on Paris time; a record that says "FR" with
        // another zone (an overseas mosque filed under FR) is not metropolitan.
        $territory = $mosque->territory ?: $mosque->country_code;
        $metropolitan = strtoupper((string) $territory) === 'FR' && $mosque->timezone === 'Europe/Paris';

        return $this->conventions[$mosque->id] ??= $this->conventionAt(
            $metropolitan ? 'FR' : null,
            $mosque->postcode,
        );
    }

    /** @param  string|null  $territory  "FR" for metropolitan France */
    public function conventionAt(?string $territory, ?string $postcode): PlaceConvention
    {
        return $this->table->forPlace(
            $territory,
            $postcode,
            (bool) config('prayertimes.france_table', true),
            (string) config('prayertimes.elsewhere', 'mwl'),
        );
    }

    /**
     * One day at a mosque, in the shape of MosqueTimetable::day().
     *
     * @return array{date: string, times: array<string, string>, iqama: array<string, null>, jumua: string|null, source: string, method: array<string, string|null>}
     */
    public function mosqueDay(Mosque $mosque, CarbonInterface $date): array
    {
        $day = $this->day($this->conventionFor($mosque), $mosque->latitude, $mosque->longitude, $mosque->timezone, $date);
        // A Jumu'a time the mosque set itself is still its own; "Jumu'a at Dhuhr" would be a calculated time.
        $isFriday = $date->dayOfWeek === CarbonInterface::FRIDAY;
        $day['jumua'] = $isFriday && ! $mosque->jumua_as_dhuhr && filled($mosque->jumua) ? $mosque->jumua : null;

        return $day;
    }

    /**
     * One day at any place, with its date read in the place's own time zone.
     *
     * @return array{date: string, times: array<string, string>, iqama: array<string, null>, jumua: null, source: string, method: array<string, string|null>}
     */
    public function day(PlaceConvention $convention, float $lat, float $lng, string $timezone, CarbonInterface $date): array
    {
        $minutes = SpecEvaluator::computeDay(
            $date->year, $date->month, $date->day, $lat, $lng, $timezone, $convention->specs,
        );
        $times = [];
        foreach (self::NAMES as $engine => $name) {
            // Isha after midnight comes back as ≥ 1440 and is shown on the clock ("00:04").
            $times[$name] = MosqueTimetable::clock($minutes[$engine]);
        }

        return [
            'date' => $date->toDateString(),
            'times' => $times,
            'iqama' => array_fill_keys(MosqueTimetable::IQAMA_PRAYERS, null),
            'jumua' => null,
            'source' => MosqueTimetable::SOURCE_CALCULATED,
            'method' => $convention->toArray(),
        ];
    }
}
