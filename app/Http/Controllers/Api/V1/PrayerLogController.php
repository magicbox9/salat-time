<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\PrayerLog;
use App\Services\Hasanat\PrayerLogPresenter;
use App\Services\Hasanat\PrayerTracker;
use App\Services\Hasanat\TrackerClock;
use Carbon\CarbonImmutable;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Routing\Controllers\HasMiddleware;
use Illuminate\Support\Collection;
use Illuminate\Validation\ValidationException;

/** Companion apps: read and record tracker logs (sensor metrics included). */
class PrayerLogController extends Controller implements HasMiddleware
{
    /** Longest span one request may read. */
    public const MAX_DAYS = 92;

    public static function middleware(): array
    {
        return [ApiError::localized()];
    }

    public function index(Request $request, PrayerLogPresenter $presenter): JsonResponse
    {
        $data = $request->validate([
            'from' => ['nullable', 'date_format:Y-m-d'],
            'to' => ['nullable', 'date_format:Y-m-d'],
        ]);
        $user = $request->user();
        $clock = TrackerClock::for($user, ApiError::deviceTimezone($request));

        $to = isset($data['to']) ? CarbonImmutable::createFromFormat('!Y-m-d', $data['to'], $clock->timezone) : $clock->today();
        $from = isset($data['from']) ? CarbonImmutable::createFromFormat('!Y-m-d', $data['from'], $clock->timezone) : $to->subDays(29);
        if ($from->gt($to)) {
            throw ValidationException::withMessages(['from' => ui('prayers.api_range_order')]);
        }
        if ((int) $from->diffInDays($to) + 1 > self::MAX_DAYS) {
            throw ValidationException::withMessages(['to' => ui('prayers.api_range_limit', ['days' => self::MAX_DAYS])]);
        }

        $order = array_flip(PrayerLog::PRAYERS);
        /** @var Collection<int, PrayerLog> $rows */
        $rows = $user->prayerLogs()
            ->whereBetween('prayer_date', [$from->toDateString(), $to->toDateString()])
            ->get();
        $logs = $rows
            ->sortBy(fn (PrayerLog $log) => PrayerLogPresenter::dateOf($log).'-'.($order[$log->prayer] ?? 9))
            ->values();

        return response()->json([
            'data' => $logs->map(fn (PrayerLog $log) => $presenter->present($log))->all(),
            'meta' => [
                'from' => $from->toDateString(),
                'to' => $to->toDateString(),
                'count' => $logs->count(),
                'total_hasanat' => (int) $logs->sum('hasanat'),
            ],
        ]);
    }

    public function store(Request $request, PrayerTracker $tracker, PrayerLogPresenter $presenter): JsonResponse
    {
        $data = $request->validate(PrayerTracker::rules(fromPhone: true));
        $user = $request->user();
        $clock = TrackerClock::for($user, $data['tz'] ?? ApiError::deviceTimezone($request));
        [$log, $created] = $tracker->record($user, $data, $clock, (string) $data['source']);

        return response()->json(['data' => $presenter->present($log)], $created ? 201 : 200);
    }
}
