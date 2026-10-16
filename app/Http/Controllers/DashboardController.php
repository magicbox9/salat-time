<?php

namespace App\Http\Controllers;

use App\Models\MosqueClaim;
use App\Services\Hasanat\TrackerClock;
use App\Services\Hasanat\TrackerStats;
use App\Services\PrayerTimes\MosqueTimetable;
use App\Support\MosquePresenter;
use Illuminate\Http\Request;
use Inertia\Inertia;
use Inertia\Response;

/** "My space": the signed-in visitor's mosque, today's prayers and open requests. */
class DashboardController extends Controller
{
    public function __invoke(Request $request, MosqueTimetable $timetable, TrackerStats $stats): Response
    {
        $user = $request->user();
        $clock = TrackerClock::for($user);
        $mosque = $clock->mosque;
        $summary = $stats->summary($user, $clock);

        return Inertia::render('dashboard', [
            'mosque' => $mosque ? [
                ...MosquePresenter::summary($mosque),
                'live' => $timetable->live($mosque),
            ] : null,
            'favoritesCount' => $user->favoriteMosques()->count(),
            'tracker' => [
                'total_hasanat' => $summary['total_hasanat'],
                'streak' => $summary['streak'],
                'today' => [
                    'hasanat' => $summary['today']['hasanat'],
                    'prayed' => $summary['today']['prayed'],
                ],
            ],
            'claims' => [
                'pending' => $user->hasMany(MosqueClaim::class)->where('status', MosqueClaim::PENDING)->count(),
                'total' => $user->hasMany(MosqueClaim::class)->count(),
            ],
        ]);
    }
}
