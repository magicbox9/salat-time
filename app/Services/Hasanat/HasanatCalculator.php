<?php

namespace App\Services\Hasanat;

use App\Models\PrayerLog;
use Carbon\CarbonInterface;

/**
 * Turns one logged prayer into hasanat points (rules and numbers in
 * config/hasanat.php). Pure: no database, no clock — the caller passes the
 * streak length. Points are encouragement only; Allah alone knows the true reward.
 */
class HasanatCalculator
{
    /** @var array<string, mixed> */
    private array $config;

    /** @param  array<string, mixed>|null  $config  defaults to config('hasanat') */
    public function __construct(?array $config = null)
    {
        $this->config = $config ?? (array) config('hasanat');
    }

    /**
     * Points for one prayer, part by part.
     *
     * @param  array<string, mixed>|null  $metrics  rakaat, stillness … (phone apps)
     * @return array{base: int, mosque: int, congregation: int, streak: int, khushu: int, rakaat: int, total: int}
     */
    public function breakdown(
        string $prayer,
        string $status,
        string $place = 'home',
        bool $inCongregation = false,
        ?array $metrics = null,
        int $streakDays = 0,
        bool $isFriday = false,
    ): array {
        $parts = ['base' => 0, 'mosque' => 0, 'congregation' => 0, 'streak' => 0, 'khushu' => 0, 'rakaat' => 0];

        $parts['base'] = (int) ($this->config['base'][$status] ?? 0);
        // A missed prayer earns nothing, whatever else was recorded.
        if ($status === 'missed' || $parts['base'] === 0) {
            return [...$parts, 'base' => 0, 'total' => 0];
        }

        if ($place === 'mosque') {
            $parts['mosque'] = (int) ($this->config['place']['mosque'] ?? 0);
        }

        if ($inCongregation) {
            $congregation = $this->config['congregation'] ?? [];
            $parts['congregation'] = (int) ($congregation[$prayer] ?? $congregation['default'] ?? 0);
        }

        $parts['streak'] = $this->streakBonus($status, $streakDays);

        if ($metrics) {
            $parts['khushu'] = $this->khushuBonus($metrics['stillness'] ?? null);
            $parts['rakaat'] = $this->rakaatBonus($prayer, $metrics['rakaat'] ?? null, $place, $inCongregation, $isFriday);
        }

        return [...$parts, 'total' => array_sum($parts)];
    }

    /** Total points for a stored log. */
    public function forLog(PrayerLog $log, int $streakDays = 0): int
    {
        return $this->breakdownForLog($log, $streakDays)['total'];
    }

    /** @return array{base: int, mosque: int, congregation: int, streak: int, khushu: int, rakaat: int, total: int} */
    public function breakdownForLog(PrayerLog $log, int $streakDays = 0): array
    {
        /** @var CarbonInterface|null $date */
        $date = $log->prayer_date;
        /** @var array<string, mixed>|null $metrics */
        $metrics = $log->metrics;

        return $this->breakdown(
            (string) $log->prayer,
            (string) $log->status,
            (string) $log->place,
            (bool) $log->in_congregation,
            $metrics ?: null,
            $streakDays,
            $date !== null && $date->isFriday(),
        );
    }

    /**
     * Statuses that count a prayer as prayed for streaks.
     *
     * @return list<string>
     */
    public function streakStatuses(): array
    {
        return array_values(array_map('strval', (array) ($this->config['streak']['statuses'] ?? ['on_time', 'late', 'qada'])));
    }

    public function maxStreakDays(): int
    {
        return max(0, (int) ($this->config['streak']['max_days'] ?? 7));
    }

    /** Fard rakaat for a prayer; Friday Dhuhr prayed at the mosque in congregation is Jumu'a (2). */
    public function fardRakaat(string $prayer, string $place = 'home', bool $inCongregation = false, bool $isFriday = false): int
    {
        $fard = $this->config['fard_rakaat'] ?? [];
        if ($prayer === 'dhuhr' && $isFriday && $place === 'mosque' && $inCongregation) {
            return (int) ($fard['jumua'] ?? 2);
        }

        return (int) ($fard[$prayer] ?? 0);
    }

    private function streakBonus(string $status, int $streakDays): int
    {
        if ($streakDays <= 0 || ! in_array($status, $this->streakStatuses(), true)) {
            return 0;
        }

        return min($streakDays, $this->maxStreakDays()) * (int) ($this->config['streak']['per_day'] ?? 0);
    }

    private function khushuBonus(mixed $stillness): int
    {
        if (! is_numeric($stillness)) {
            return 0;
        }
        $threshold = (float) ($this->config['metrics']['khushu']['threshold'] ?? 0);
        $max = (int) ($this->config['metrics']['khushu']['max'] ?? 0);
        $value = min(1.0, max(0.0, (float) $stillness));
        if ($value <= $threshold || $threshold >= 1.0) {
            return 0;
        }

        // The epsilon keeps exact halves (0.6 → 2.5) from rounding down through float error.
        return (int) round(($value - $threshold) / (1 - $threshold) * $max + 1e-9);
    }

    private function rakaatBonus(string $prayer, mixed $rakaat, string $place, bool $inCongregation, bool $isFriday): int
    {
        if (! is_numeric($rakaat)) {
            return 0;
        }
        $fard = $this->fardRakaat($prayer, $place, $inCongregation, $isFriday);

        return $fard > 0 && (int) $rakaat >= $fard ? (int) ($this->config['metrics']['complete_rakaat'] ?? 0) : 0;
    }
}
