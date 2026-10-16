<?php

namespace App\Services\Hasanat;

use App\Models\PrayerLog;
use App\Models\User;
use Carbon\CarbonImmutable;
use Illuminate\Support\Collection;
use Illuminate\Support\Facades\DB;

/** Totals, streaks, week grid, month heat-map and badges for one person. */
class TrackerStats
{
    public function __construct(
        private readonly HasanatCalculator $calculator,
        private readonly PrayerLogPresenter $presenter,
    ) {}

    /**
     * Counts used by the totals and the badges, in one query.
     *
     * @return array{total_hasanat: int, logged: int, prayed: int, on_time: int, fajr_mosque: int, congregation: int}
     */
    public function counts(User $user): array
    {
        $row = (array) DB::table('prayer_logs')->where('user_id', $user->id)->selectRaw(
            "coalesce(sum(hasanat), 0) AS total_hasanat,
             count(*) AS logged,
             count(*) FILTER (WHERE status = ANY(?::text[])) AS prayed,
             count(*) FILTER (WHERE status = 'on_time') AS on_time,
             count(*) FILTER (WHERE prayer = 'fajr' AND place = 'mosque' AND status IN ('on_time', 'late')) AS fajr_mosque,
             count(*) FILTER (WHERE in_congregation AND status <> 'missed') AS congregation",
            [$this->prayedStatuses()],
        )->first();

        return [
            'total_hasanat' => (int) ($row['total_hasanat'] ?? 0),
            'logged' => (int) ($row['logged'] ?? 0),
            'prayed' => (int) ($row['prayed'] ?? 0),
            'on_time' => (int) ($row['on_time'] ?? 0),
            'fajr_mosque' => (int) ($row['fajr_mosque'] ?? 0),
            'congregation' => (int) ($row['congregation'] ?? 0),
        ];
    }

    /**
     * Days in a row with all five prayed. The current streak still counts
     * yesterday's run while today is in progress.
     *
     * @return array{current: int, best: int}
     */
    public function streaks(User $user, CarbonImmutable $today): array
    {
        $dates = $this->completeDates($user);
        $best = 0;
        $run = 0;
        $previous = null;
        foreach ($dates as $date) {
            $run = $previous !== null && CarbonImmutable::parse($previous)->addDay()->toDateString() === $date ? $run + 1 : 1;
            $best = max($best, $run);
            $previous = $date;
        }

        $set = array_flip($dates);
        $cursor = isset($set[$today->toDateString()]) ? $today : $today->subDay();
        $current = 0;
        while (isset($set[$cursor->toDateString()])) {
            $current++;
            $cursor = $cursor->subDay();
        }

        return ['current' => $current, 'best' => $best];
    }

    /**
     * The logs of a span of days, keyed by date then prayer.
     *
     * @return list<array{date: string, prayers: array<string, array<string, mixed>|null>, hasanat: int}>
     */
    public function days(User $user, CarbonImmutable $from, CarbonImmutable $to): array
    {
        /** @var Collection<int, PrayerLog> $rows */
        $rows = $user->prayerLogs()
            ->whereBetween('prayer_date', [$from->toDateString(), $to->toDateString()])
            ->get();
        /** @var Collection<string, Collection<int, PrayerLog>> $logs */
        $logs = $rows->groupBy(fn (PrayerLog $log) => PrayerLogPresenter::dateOf($log));

        $out = [];
        for ($day = $from; $day->lte($to); $day = $day->addDay()) {
            $date = $day->toDateString();
            $prayers = array_fill_keys(PrayerLog::PRAYERS, null);
            foreach ($logs[$date] ?? [] as $log) {
                $prayers[$log->prayer] = $this->presenter->present($log);
            }
            $out[] = [
                'date' => $date,
                'prayers' => $prayers,
                'hasanat' => (int) collect($logs[$date] ?? [])->sum('hasanat'),
            ];
        }

        return $out;
    }

    /**
     * A calendar month: prayers prayed (0–5) and hasanat per day.
     *
     * @return array{month: string, days: list<array{date: string, prayed: int, logged: int, hasanat: int}>}
     */
    public function month(User $user, CarbonImmutable $month): array
    {
        $first = $month->startOfMonth();
        $last = $month->endOfMonth();
        $rows = DB::table('prayer_logs')
            ->where('user_id', $user->id)
            ->whereBetween('prayer_date', [$first->toDateString(), $last->toDateString()])
            ->groupBy('prayer_date')
            ->selectRaw(
                'prayer_date::text AS date, count(*) AS logged, count(*) FILTER (WHERE status = ANY(?::text[])) AS prayed, coalesce(sum(hasanat), 0) AS hasanat',
                [$this->prayedStatuses()],
            )
            ->get()
            ->keyBy('date');

        $days = [];
        for ($day = $first; $day->lte($last); $day = $day->addDay()) {
            $row = $rows[$day->toDateString()] ?? null;
            $days[] = [
                'date' => $day->toDateString(),
                'prayed' => (int) ($row->prayed ?? 0),
                'logged' => (int) ($row->logged ?? 0),
                'hasanat' => (int) ($row->hasanat ?? 0),
            ];
        }

        return ['month' => $first->format('Y-m'), 'days' => $days];
    }

    /**
     * Gentle milestones with progress.
     *
     * @param  array<string, int>  $counts
     * @return list<array{key: string, target: int, progress: int, earned: bool}>
     */
    public function badges(array $counts, int $bestStreak): array
    {
        $progress = [
            'first_prayer' => $counts['prayed'] ?? 0,
            'on_time_100' => $counts['on_time'] ?? 0,
            'fajr_mosque_10' => $counts['fajr_mosque'] ?? 0,
            'congregation_40' => $counts['congregation'] ?? 0,
            'streak_7' => $bestStreak,
            'streak_30' => $bestStreak,
        ];

        $badges = [];
        foreach ((array) config('hasanat.badges', []) as $key => $target) {
            $value = min((int) $target, $progress[$key] ?? 0);
            $badges[] = ['key' => (string) $key, 'target' => (int) $target, 'progress' => $value, 'earned' => $value >= (int) $target];
        }

        return $badges;
    }

    /**
     * Everything the summary cards need.
     *
     * @return array<string, mixed>
     */
    public function summary(User $user, TrackerClock $clock): array
    {
        $counts = $this->counts($user);
        $streaks = $this->streaks($user, $clock->today());
        $today = $this->days($user, $clock->today(), $clock->today())[0];

        return [
            'total_hasanat' => $counts['total_hasanat'],
            'prayers_logged' => $counts['logged'],
            'prayers_prayed' => $counts['prayed'],
            'streak' => $streaks,
            'today' => [
                'date' => $today['date'],
                'hasanat' => $today['hasanat'],
                'prayed' => count(array_filter($today['prayers'], fn ($log) => $log && $log['status'] !== 'missed')),
                'logs' => $today['prayers'],
            ],
            'badges' => $this->badges($counts, $streaks['best']),
        ];
    }

    /** @return list<string> dates (Y-m-d, ascending) with all five prayers prayed */
    private function completeDates(User $user): array
    {
        $dates = DB::table('prayer_logs')
            ->where('user_id', $user->id)
            ->whereIn('status', $this->calculator->streakStatuses())
            ->groupBy('prayer_date')
            ->havingRaw('count(DISTINCT prayer) = ?', [count(PrayerLog::PRAYERS)])
            ->orderBy('prayer_date')
            ->selectRaw('prayer_date::text AS date')
            ->pluck('date')
            ->map(fn ($date) => (string) $date)
            ->all();

        return array_values($dates);
    }

    /** The statuses that count as prayed, as a PostgreSQL text[] literal for a binding. */
    private function prayedStatuses(): string
    {
        return '{'.implode(',', $this->calculator->streakStatuses()).'}';
    }
}
