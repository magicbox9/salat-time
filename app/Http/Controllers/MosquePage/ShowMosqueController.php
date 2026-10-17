<?php

namespace App\Http\Controllers\MosquePage;

use App\Http\Controllers\Controller;
use App\Http\Controllers\MosquePage\Support\HomeSections;
use App\Http\Controllers\MosquePage\Support\MosqueProfile;
use App\Http\Controllers\MosquePage\Support\MosqueSite;
use App\Http\Controllers\MosquePage\Support\PostPresenter;
use App\Models\Mosque;
use App\Services\PrayerTimes\MosqueTimetable;
use App\Support\MosquePresenter;
use Illuminate\Http\Request;
use Inertia\Inertia;
use Inertia\Response;

/**
 * A mosque's home page: its published times at the centre, then its news,
 * events, campaigns and how to reach it.
 */
class ShowMosqueController extends Controller
{
    /** Search radii (km) for nearby mosques that do publish times. */
    private const NEARBY_RADII = [30, 150, 600];

    public function __invoke(Request $request, Mosque $mosque, MosqueTimetable $timetable): Response
    {
        $user = $request->user();
        $canManage = $user?->can('manage', $mosque) ?? false;
        $live = null;
        $getLive = function () use (&$live, $timetable, $mosque): array {
            return $live ??= $timetable->live($mosque);
        };
        $shareUrl = route('mosques.show', $mosque);

        // Closures: a partial reload (the favourite buttons reload only `viewer`)
        // runs only the queries of the props it asks for.
        return Inertia::render('mosques/show', [
            'site' => fn () => MosqueSite::shell($mosque),
            'mosque' => function () use ($mosque): array {
                $mosque->loadCount('calendars');

                return MosqueProfile::details($mosque);
            },
            'live' => $getLive,
            'nearbyWithTimes' => fn () => $getLive()['today'] === null ? $this->nearbyWithTimes($mosque) : [],
            'viewer' => fn () => MosqueProfile::viewer($user, $mosque, $canManage),
            'pinned' => fn () => HomeSections::pinned($mosque),
            'latest' => fn () => HomeSections::latestByCategory($mosque),
            'events' => fn () => HomeSections::upcomingEvents($mosque),
            'aboutPage' => fn () => HomeSections::aboutPage($mosque),
            'shareUrl' => $shareUrl,
            'meta' => fn () => MosqueSite::meta(
                $mosque->name,
                $mosque->tagline ?: ($mosque->description ?: ui('mosquesite.meta_home', [
                    'name' => $mosque->name,
                    'place' => trim($mosque->postcode.' '.$mosque->city),
                ])),
                PostPresenter::url($mosque->cover_path),
                $shareUrl,
            ),
        ]);
    }

    /**
     * The closest mosques that publish their times, for a mosque that does not.
     *
     * @return array<int, array<string, mixed>>
     */
    private function nearbyWithTimes(Mosque $mosque): array
    {
        foreach (self::NEARBY_RADII as $radiusKm) {
            $nearby = Mosque::near($mosque->latitude, $mosque->longitude, $radiusKm)
                ->whereKeyNot($mosque->id)
                ->whereHas('calendars')
                ->withCount('calendars')
                ->limit(6)
                ->get();
            if ($nearby->isNotEmpty()) {
                return $nearby->map(fn (Mosque $m) => MosquePresenter::summary($m))->values()->all();
            }
        }

        return [];
    }
}
