<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Services\Hasanat\TrackerClock;
use App\Services\Hasanat\TrackerStats;
use App\Services\PrayerTimes\MosqueTimetable;
use App\Support\MosquePresenter;
use Carbon\CarbonImmutable;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Routing\Controllers\HasMiddleware;

/** Companion apps: who I am, my mosque's published times, my tracker summary. */
class MeController extends Controller implements HasMiddleware
{
    public static function middleware(): array
    {
        return [ApiError::localized()];
    }

    public function show(Request $request): JsonResponse
    {
        $user = $request->user();
        $mosque = TrackerClock::primaryMosque($user);

        return response()->json(['data' => [
            'id' => $user->id,
            'name' => $user->name,
            'email' => $user->email,
            'email_verified' => $user->email_verified_at !== null,
            'locale' => $user->locale,
            'created_at' => $user->created_at?->toIso8601String(),
            'mosque' => $mosque ? MosquePresenter::summary($mosque) : null,
        ]]);
    }

    /**
     * My mosque's day for ?date= (default: today in the mosque's time zone):
     * its published times, or calculated ones (day.source = "calculated", no
     * iqama) when it publishes none.
     */
    public function times(Request $request, MosqueTimetable $timetable): JsonResponse
    {
        $data = $request->validate(['date' => ['nullable', 'date_format:Y-m-d']]);
        $mosque = TrackerClock::primaryMosque($request->user());
        if (! $mosque) {
            return ApiError::response('no_mosque', ui('prayers.api_no_mosque'), 404);
        }

        $date = isset($data['date'])
            ? CarbonImmutable::createFromFormat('!Y-m-d', $data['date'], $mosque->timezone)
            : CarbonImmutable::now($mosque->timezone);
        // Null only for a gap in the mosque's own calendar, which is never filled with a guess.
        $day = $timetable->day($mosque, $date);

        return response()->json(['data' => [
            'mosque' => MosquePresenter::summary($mosque),
            'timezone' => $mosque->timezone,
            'date' => $date->toDateString(),
            'has_times' => $day !== null,
            'source' => $day['source'] ?? null,
            'day' => $day,
        ]]);
    }

    public function summary(Request $request, TrackerStats $stats): JsonResponse
    {
        $user = $request->user();
        $clock = TrackerClock::for($user, ApiError::deviceTimezone($request));

        return response()->json(['data' => [
            'timezone' => $clock->timezone,
            ...$stats->summary($user, $clock),
        ]]);
    }
}
