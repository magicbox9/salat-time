<?php

namespace App\Http\Controllers\Mosques;

use App\Http\Controllers\Controller;
use App\Models\Mosque;
use App\Services\PrayerTimes\MosqueTimetable;
use Carbon\CarbonImmutable;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

/** A mosque's published times as JSON (map popups, live widgets, the timetable). */
class MosqueTimesController extends Controller
{
    public function __invoke(Request $request, Mosque $mosque, MosqueTimetable $timetable): JsonResponse
    {
        $data = $request->validate([
            'from' => ['nullable', 'date_format:Y-m-d'],
            'days' => ['nullable', 'integer', 'min:1', 'max:62'],
        ]);
        $live = $timetable->live($mosque);
        $from = isset($data['from'])
            ? CarbonImmutable::parse($data['from'], $mosque->timezone)
            : CarbonImmutable::now($mosque->timezone);

        return response()->json([
            ...$live,
            'days' => isset($data['days']) ? $timetable->range($mosque, $from, (int) $data['days']) : [],
        ]);
    }
}
