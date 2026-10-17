<?php

namespace App\Services\PrayerTimes\Calculation;

/**
 * "Match my mosque" (SPEC §6): from a mosque's Fajr or Isha on a few days,
 * pick the candidate convention and minute adjustment that reproduce them.
 */
final class MosqueMatcher
{
    /** Adjustments tried, smallest first and negatives first: 0, −1, 1, −2, 2, … −10, 10. */
    public static function adjustmentOrder(): array
    {
        $order = range(-10, 10);
        usort($order, fn (int $a, int $b) => (abs($a) <=> abs($b)) ?: ($a <=> $b));

        return $order;
    }

    /**
     * @param  list<array{y: int, m: int, d: int, minute: int}>  $typed  the mosque's times for one prayer
     * @param  list<array<string, mixed>>  $candidates  [département default, ...presets]
     * @return array{candidate: int, adjustment: int}
     */
    public static function match(string $prayer, array $typed, float $lat, float $lon, string $timezone, array $candidates): array
    {
        $predicted = array_map(
            fn (array $spec) => array_map(
                fn (array $t) => SpecEvaluator::evaluate(new SolarDay($t['y'], $t['m'], $t['d'], $lat, $lon, $timezone), $prayer, $spec),
                $typed,
            ),
            $candidates,
        );

        $best = null;
        foreach (self::adjustmentOrder() as $adjustment) {
            foreach ($predicted as $candidate => $minutes) {
                $error = 0;
                foreach ($typed as $k => $t) {
                    $error += abs($minutes[$k] + $adjustment - $t['minute']);
                }
                // Strictly smaller only: ties keep the smaller adjustment, then the earlier candidate.
                if ($best === null || $error < $best['error']) {
                    $best = ['error' => $error, 'candidate' => $candidate, 'adjustment' => $adjustment];
                }
            }
        }

        return ['candidate' => $best['candidate'], 'adjustment' => $best['adjustment']];
    }
}
