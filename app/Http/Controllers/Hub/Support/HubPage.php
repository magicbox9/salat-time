<?php

namespace App\Http\Controllers\Hub\Support;

use App\Http\Controllers\Discover\Support\MosqueCards;
use App\Models\Mosque;
use App\Models\MosquePost;
use App\Models\MosquePostCategory;
use App\Models\User;
use App\Services\Hasanat\TrackerClock;
use App\Services\Hasanat\TrackerStats;
use App\Services\PrayerTimes\MosqueTimetable;
use App\Support\Markdown;
use App\Support\MosquePresenter;
use Carbon\CarbonImmutable;
use Carbon\CarbonInterface;
use Illuminate\Http\Request;
use Inertia\Inertia;
use Inertia\Response;

/**
 * The hub ("/" once a mosque is chosen): the visitor's mosque, its published
 * times live, a tracker check-in, its latest posts and, when it publishes no
 * times, the closest mosques that do. Props are closures so a partial reload
 * (after midnight: live + tracker) only runs what it asks for.
 */
class HubPage
{
    /** Search radii (km) for nearby mosques that publish their times. */
    private const NEARBY_RADII = [30, 150, 600];

    private const NEARBY_LIMIT = 6;

    private const POSTS = 3;

    public function __construct(
        private readonly MosqueTimetable $timetable,
        private readonly TrackerStats $stats,
    ) {}

    public function render(Request $request, Mosque $mosque, string $chosenBy): Response
    {
        $user = $request->user();
        $live = null;
        $getLive = function () use (&$live, $mosque): array {
            return $live ??= $this->live($mosque);
        };

        return Inertia::render('hub/index', [
            'mosque' => fn () => $this->mosque($mosque),
            'chosenBy' => $chosenBy,
            'live' => $getLive,
            'nearbyWithTimes' => fn () => $getLive()['today'] === null ? $this->nearbyWithTimes($mosque, $user) : [],
            'posts' => fn () => $this->posts($mosque),
            'tracker' => fn () => $user instanceof User && $user->hasVerifiedEmail() ? $this->tracker($user) : null,
            'preferences' => fn () => $user instanceof User ? HubPreferences::of($user) : null,
            'defaults' => HubPreferences::DEFAULTS,
            'canManage' => fn () => $user?->can('manage', $mosque) ?? false,
        ]);
    }

    /** @return array<string, mixed> */
    private function mosque(Mosque $mosque): array
    {
        $mosque->loadCount('calendars');

        return [
            ...MosquePresenter::summary($mosque),
            'tagline' => $mosque->tagline,
            'accent_color' => is_string($mosque->accent_color) && preg_match('/^#[0-9a-fA-F]{6}$/', $mosque->accent_color)
                ? $mosque->accent_color
                : null,
        ];
    }

    /** @return array<int, array<string, mixed>> */
    private function posts(Mosque $mosque): array
    {
        return MosquePost::query()
            ->where('mosque_id', $mosque->id)
            ->whereNotNull('published_at')
            ->where('published_at', '<=', now())
            ->with('category:id,name,slug')
            ->orderByDesc('published_at')
            ->orderByDesc('id')
            ->limit(self::POSTS)
            ->get(['id', 'mosque_id', 'category_id', 'type', 'title', 'slug', 'excerpt', 'body', 'image_path', 'published_at'])
            ->map(function (MosquePost $post) use ($mosque): array {
                $publishedAt = $post->getAttribute('published_at');
                $category = $post->getRelation('category');

                return [
                    'id' => $post->id,
                    'type' => $post->type,
                    'title' => $post->title,
                    'excerpt' => $post->excerpt ?: Markdown::excerpt($post->body, 160),
                    'image_url' => $post->image_path ? asset('storage/'.$post->image_path) : null,
                    'published_at' => $publishedAt instanceof CarbonInterface ? $publishedAt->toIso8601String() : null,
                    'category' => $category instanceof MosquePostCategory ? $category->name : null,
                    'url' => $post->slug
                        ? '/mosques/'.$mosque->slug.'/blog/'.$post->slug
                        : '/mosques/'.$mosque->slug,
                ];
            })
            ->values()
            ->all();
    }

    /**
     * Today and tomorrow (MosqueTimetable::live), plus the evening before
     * while it still holds the night: summer timetables publish Isha after
     * midnight ("00:02"), and that Isha belongs to the previous day's
     * prayers. The page keeps that night until its Isha is over.
     *
     * @return array<string, mixed>
     */
    private function live(Mosque $mosque): array
    {
        $live = $this->timetable->live($mosque);
        $live['yesterday'] = null;

        if ($live['today'] !== null) {
            $before = $this->timetable->day($mosque, CarbonImmutable::parse($live['now'])->setTimezone($mosque->timezone)->subDay());
            if ($before !== null && self::ishaAfterMidnight($before['times'])) {
                $live['yesterday'] = $before;
            }
        }

        return $live;
    }

    /**
     * An Isha earlier than both Maghrib and Fajr on the clock is the same
     * night's, after midnight (a mistyped "09:45" is not).
     *
     * @param  array<string, string>  $times
     */
    private static function ishaAfterMidnight(array $times): bool
    {
        $isha = MosqueTimetable::minutes($times['isha'] ?? '');
        $maghrib = MosqueTimetable::minutes($times['maghrib'] ?? '');
        $fajr = MosqueTimetable::minutes($times['fajr'] ?? '');

        return $isha !== null && $maghrib !== null && $fajr !== null && $isha < $maghrib && $isha < $fajr;
    }

    /**
     * Today's tracker logs, for the check-in card (same day as /prayers),
     * and the day before's (an Isha after midnight is still checked in on
     * its own evening).
     *
     * @return array{date: string, timezone: string, logs: array<string, array{status: string, hasanat: int}|null>, previous: array{date: string, logs: array<string, array{status: string, hasanat: int}|null>}}
     */
    private function tracker(User $user): array
    {
        $clock = TrackerClock::for($user);
        [$before, $today] = $this->stats->days($user, $clock->today()->subDay(), $clock->today());
        $logs = fn (array $day): array => array_map(
            fn (?array $log) => $log ? ['status' => (string) $log['status'], 'hasanat' => (int) $log['hasanat']] : null,
            $day['prayers'],
        );

        return [
            'date' => $today['date'],
            'timezone' => $clock->timezone,
            'logs' => $logs($today),
            'previous' => ['date' => $before['date'], 'logs' => $logs($before)],
        ];
    }

    /** @return array<int, array<string, mixed>> */
    private function nearbyWithTimes(Mosque $mosque, ?User $user): array
    {
        foreach (self::NEARBY_RADII as $radiusKm) {
            $nearby = Mosque::near($mosque->latitude, $mosque->longitude, $radiusKm)
                ->whereKeyNot($mosque->id)
                ->whereHas('calendars')
                ->withCount('calendars')
                ->limit(self::NEARBY_LIMIT)
                ->get();
            if ($nearby->isNotEmpty()) {
                return MosqueCards::make($nearby, $user);
            }
        }

        return [];
    }
}
