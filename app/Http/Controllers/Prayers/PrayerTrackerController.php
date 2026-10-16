<?php

namespace App\Http\Controllers\Prayers;

use App\Http\Controllers\Controller;
use App\Models\User;
use App\Services\Hasanat\TrackerClock;
use App\Services\Hasanat\TrackerStats;
use App\Services\PrayerTimes\MosqueTimetable;
use App\Support\MosquePresenter;
use Carbon\CarbonImmutable;
use Illuminate\Http\Request;
use Inertia\Inertia;
use Inertia\Response;

/** The personal prayer tracker: today's prayers, hasanat, streaks, week and month. */
class PrayerTrackerController extends Controller
{
    /** How far back the month heat-map can go. */
    private const MONTHS_BACK = 24;

    public function __invoke(Request $request, TrackerStats $stats, MosqueTimetable $timetable): Response
    {
        $data = $request->validate([
            'tz' => ['nullable', 'string', 'max:64'],
            'month' => ['nullable', 'date_format:Y-m'],
        ]);
        $user = $request->user();
        $clock = TrackerClock::for($user, $data['tz'] ?? null);
        $today = $clock->today();
        $mosque = $clock->mosque;

        // Props are lazy so a partial reload (e.g. the month heat-map) only computes what it asks for.
        $memo = [];
        $get = function (string $key, callable $make) use (&$memo) {
            return $memo[$key] ??= $make();
        };
        $week = fn () => $get('week', fn () => $stats->days($user, $today->subDays(6), $today));
        $counts = fn () => $get('counts', fn () => $stats->counts($user));
        $streaks = fn () => $get('streaks', fn () => $stats->streaks($user, $today));

        return Inertia::render('prayers/index', [
            'clock' => [
                'timezone' => $clock->timezone,
                'source' => $clock->source,
                'now' => $clock->now->toIso8601String(),
                'today' => $clock->todayString(),
                'editable_from' => $clock->oldestEditable()->toDateString(),
            ],
            'mosque' => fn () => $mosque ? MosquePresenter::summary($mosque) : null,
            'times' => fn () => $mosque ? [
                'today' => $timetable->day($mosque, $clock->now),
                'tomorrow' => $timetable->day($mosque, $clock->now->addDay()),
            ] : null,
            'today' => fn () => last($week()),
            'week' => $week,
            'stats' => fn () => [
                'total_hasanat' => $counts()['total_hasanat'],
                'prayers_prayed' => $counts()['prayed'],
                'streak' => $streaks(),
            ],
            'badges' => fn () => $stats->badges($counts(), $streaks()['best']),
            'rules' => fn () => $this->rules(),
            'month' => fn () => $this->monthData($stats, $user, $data['month'] ?? null, $today),
        ]);
    }

    /** @return array<string, mixed> */
    private function monthData(TrackerStats $stats, User $user, ?string $value, CarbonImmutable $today): array
    {
        $current = $today->startOfMonth();
        $oldest = $current->subMonths(self::MONTHS_BACK);
        $month = $value ? CarbonImmutable::createFromFormat('!Y-m', $value, $today->timezone)->startOfMonth() : $current;
        $month = $month->gt($current) ? $current : ($month->lt($oldest) ? $oldest : $month);

        return [
            ...$stats->month($user, $month),
            'previous' => $month->gt($oldest) ? $month->subMonth()->format('Y-m') : null,
            'next' => $month->lt($current) ? $month->addMonth()->format('Y-m') : null,
        ];
    }

    /**
     * The point values explained on the page.
     *
     * @return array<string, mixed>
     */
    private function rules(): array
    {
        $config = config('hasanat');

        return [
            'base' => $config['base'],
            'mosque' => (int) $config['place']['mosque'],
            'congregation' => (int) $config['congregation']['default'],
            'congregation_fajr_isha' => (int) max($config['congregation']['fajr'] ?? 0, $config['congregation']['isha'] ?? 0),
            'streak_per_day' => (int) $config['streak']['per_day'],
            'streak_max_days' => (int) $config['streak']['max_days'],
            'khushu_max' => (int) $config['metrics']['khushu']['max'],
            'complete_rakaat' => (int) $config['metrics']['complete_rakaat'],
        ];
    }
}
