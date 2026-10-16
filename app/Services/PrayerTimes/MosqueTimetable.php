<?php

namespace App\Services\PrayerTimes;

use App\Models\Mosque;
use App\Models\MosquePrayerCalendar;
use Carbon\CarbonImmutable;
use Carbon\CarbonInterface;

/**
 * Prayer times exactly as a mosque publishes them (its Mawaqit calendar),
 * read the same way the Mac app reads them: the row for a date is found by
 * month and day, and iqama values are either "+N" minutes after the adhan or a
 * fixed "HH:MM". Nothing is calculated or estimated here.
 */
class MosqueTimetable
{
    public const PRAYERS = ['fajr', 'shuruq', 'dhuhr', 'asr', 'maghrib', 'isha'];

    /** Prayers that have an iqama (Shuruq has none). */
    public const IQAMA_PRAYERS = ['fajr', 'dhuhr', 'asr', 'maghrib', 'isha'];

    /** @var array<int, MosquePrayerCalendar|null> */
    private array $calendars = [];

    public function hasTimes(Mosque $mosque): bool
    {
        return $this->calendar($mosque, (int) now($mosque->timezone)->year) !== null;
    }

    /** The calendar for a year; a mosque's calendar is a yearly template, so the latest one stands in. */
    public function calendar(Mosque $mosque, int $year): ?MosquePrayerCalendar
    {
        $key = $mosque->id * 10000 + $year;
        if (! array_key_exists($key, $this->calendars)) {
            $this->calendars[$key] = $mosque->calendars()
                ->orderByRaw('CASE WHEN year = ? THEN 0 ELSE 1 END', [$year])
                ->orderByDesc('year')
                ->first();
        }

        return $this->calendars[$key];
    }

    /**
     * One day's times, or null when the mosque publishes none.
     *
     * @return array{date: string, times: array<string, string>, iqama: array<string, string|null>, jumua: string|null}|null
     */
    public function day(Mosque $mosque, CarbonInterface $date): ?array
    {
        $calendar = $this->calendar($mosque, (int) $date->year);
        if (! $calendar) {
            return null;
        }
        $row = $this->row($calendar->days, $date);
        if (! $row || count($row) < 6) {
            return null;
        }
        $times = array_combine(self::PRAYERS, array_slice($row, 0, 6));
        $iqamaRow = $calendar->iqama ? $this->row($calendar->iqama, $date) : null;
        $iqama = [];
        foreach (self::IQAMA_PRAYERS as $i => $prayer) {
            $iqama[$prayer] = $iqamaRow ? self::resolveIqama((string) ($iqamaRow[$i] ?? ''), $times[$prayer]) : null;
        }
        $isFriday = $date->dayOfWeek === CarbonInterface::FRIDAY;

        return [
            'date' => $date->toDateString(),
            'times' => $times,
            'iqama' => $iqama,
            'jumua' => $isFriday ? ($mosque->jumua_as_dhuhr ? $times['dhuhr'] : $mosque->jumua) : null,
        ];
    }

    /**
     * Consecutive days starting at $from (days without times are skipped).
     *
     * @return list<array<string, mixed>>
     */
    public function range(Mosque $mosque, CarbonInterface $from, int $days): array
    {
        $out = [];
        $date = CarbonImmutable::parse($from->toDateString(), $mosque->timezone);
        for ($i = 0; $i < $days; $i++) {
            if ($day = $this->day($mosque, $date->addDays($i))) {
                $out[] = $day;
            }
        }

        return $out;
    }

    /**
     * Everything a live page needs: today and tomorrow (for the countdown after
     * Isha) in the mosque's own time zone.
     *
     * @return array{timezone: string, now: string, today: array<string, mixed>|null, tomorrow: array<string, mixed>|null}
     */
    public function live(Mosque $mosque): array
    {
        $now = CarbonImmutable::now($mosque->timezone);

        return [
            'timezone' => $mosque->timezone,
            'now' => $now->toIso8601String(),
            'today' => $this->day($mosque, $now),
            'tomorrow' => $this->day($mosque, $now->addDay()),
        ];
    }

    /** "+10" → adhan + 10 minutes; "13:30" → 13:30; anything else → null. */
    public static function resolveIqama(string $raw, string $adhan): ?string
    {
        $value = trim($raw);
        if ($value === '') {
            return null;
        }
        if (preg_match('/^[+-]\d{1,3}$/', $value)) {
            $base = self::minutes($adhan);

            return $base === null ? null : self::clock($base + (int) $value);
        }

        return self::minutes($value) === null ? null : $value;
    }

    public static function minutes(string $hhmm): ?int
    {
        if (! preg_match('/^(\d{1,2}):(\d{2})$/', trim($hhmm), $m)) {
            return null;
        }
        $h = (int) $m[1];
        $min = (int) $m[2];

        return $h < 48 && $min < 60 ? $h * 60 + $min : null;
    }

    public static function clock(int $minutes): string
    {
        $value = (($minutes % 1440) + 1440) % 1440;

        return sprintf('%02d:%02d', intdiv($value, 60), $value % 60);
    }

    /** @param  array<int, array<int, array<int, string>>>  $months */
    private function row(array $months, CarbonInterface $date): ?array
    {
        $month = $months[$date->month - 1] ?? null;
        $row = $month[$date->day - 1] ?? null;
        // 29 February in a calendar that has no such row: use the 28th.
        if ($row === null && $date->month === 2 && $date->day === 29) {
            $row = $month[27] ?? null;
        }

        return is_array($row) ? array_values($row) : null;
    }
}
