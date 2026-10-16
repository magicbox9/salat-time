<?php

namespace App\Http\Controllers\Discover\Support;

use App\Models\Mosque;
use App\Models\MosquePrayerCalendar;
use App\Services\PrayerTimes\MosqueTimetable;
use Carbon\CarbonImmutable;
use Illuminate\Support\Collection;

/**
 * Today's and tomorrow's published times for a whole list of mosques (map
 * cards, "my mosques"), read with one query per local date instead of one
 * per mosque. It reads exactly the rows MosqueTimetable::day() reads (same
 * calendar choice, same 29 February rule) and pulls only those two rows out
 * of each yearly JSON calendar. Nothing is calculated.
 */
class PublishedToday
{
    /**
     * @param  iterable<Mosque>  $mosques
     * @return array<int, array{today: array{date: string, times: array<string, string>}|null, tomorrow: array{date: string, times: array<string, string>}|null}>
     */
    public static function for(iterable $mosques): array
    {
        // Mosques in different time zones may already be on another date.
        $byDate = [];
        foreach ($mosques as $mosque) {
            $byDate[CarbonImmutable::now($mosque->timezone)->toDateString()][] = $mosque->id;
        }

        $out = [];
        foreach ($byDate as $date => $ids) {
            $today = CarbonImmutable::parse($date);
            $tomorrow = $today->addDay();
            [$todaySql, $todayBindings] = self::rowPath($today);
            [$tomorrowSql, $tomorrowBindings] = self::rowPath($tomorrow);
            $rows = MosquePrayerCalendar::query()
                ->whereIn('mosque_id', $ids)
                ->select(['mosque_id', 'year'])
                ->selectRaw($todaySql.' AS today_row', $todayBindings)
                ->selectRaw($tomorrowSql.' AS tomorrow_row', $tomorrowBindings)
                ->toBase()
                ->get()
                ->groupBy('mosque_id');

            foreach ($ids as $id) {
                $calendars = $rows->get($id, collect());
                $out[$id] = [
                    'today' => self::day($calendars, $today, 'today_row'),
                    'tomorrow' => self::day($calendars, $tomorrow, 'tomorrow_row'),
                ];
            }
        }

        return $out;
    }

    /**
     * @param  Collection<int, \stdClass>  $calendars
     * @return array{date: string, times: array<string, string>}|null
     */
    private static function day(Collection $calendars, CarbonImmutable $date, string $column): ?array
    {
        // As MosqueTimetable::calendar(): that year's calendar, else the latest one.
        $calendar = $calendars->first(fn ($c) => (int) $c->year === $date->year)
            ?? $calendars->sortByDesc('year')->first();
        if (! $calendar || $calendar->{$column} === null) {
            return null;
        }
        $row = json_decode((string) $calendar->{$column}, true);
        if (! is_array($row) || count($row) < 6) {
            return null;
        }

        return [
            'date' => $date->toDateString(),
            'times' => array_combine(MosqueTimetable::PRAYERS, array_map('strval', array_slice(array_values($row), 0, 6))),
        ];
    }

    /**
     * JSON path of one day's row, days[month - 1][day - 1], with its bindings.
     *
     * @return array{0: 'days -> ?::int -> ?::int'|'COALESCE(days -> ?::int -> ?::int, days -> 1 -> 27)', 1: list<int>}
     */
    private static function rowPath(CarbonImmutable $date): array
    {
        $bindings = [$date->month - 1, $date->day - 1];

        // 29 February in a calendar that has no such row: the 28th.
        return $date->month === 2 && $date->day === 29
            ? ['COALESCE(days -> ?::int -> ?::int, days -> 1 -> 27)', $bindings]
            : ['days -> ?::int -> ?::int', $bindings];
    }
}
