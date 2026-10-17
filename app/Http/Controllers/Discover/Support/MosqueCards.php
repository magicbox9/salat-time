<?php

namespace App\Http\Controllers\Discover\Support;

use App\Http\Controllers\Discover\FavoriteMosqueController;
use App\Models\Mosque;
use App\Models\User;
use App\Services\PrayerTimes\CalculatedTimes;
use App\Services\PrayerTimes\MosqueTimetable;
use App\Support\MosquePresenter;
use Carbon\CarbonImmutable;
use Illuminate\Database\Eloquent\Collection as EloquentCollection;
use Illuminate\Support\Collection;
use Illuminate\Support\Facades\DB;

/**
 * Mosque summaries for maps and lists, plus whether the visitor saved each
 * one and (optionally) today's times for the next-prayer countdown: the
 * published ones, or calculated ones (source "calculated") for a mosque that
 * publishes no calendar.
 */
class MosqueCards
{
    /**
     * @param  EloquentCollection<int, Mosque>  $mosques  loaded with withCount('calendars')
     * @return array<int, array<string, mixed>>
     */
    public static function make(EloquentCollection $mosques, ?User $user, bool $withTimes = true): array
    {
        $flags = self::favoriteFlags($mosques, $user);
        $times = $withTimes ? self::todayAndTomorrow($mosques) : [];

        return $mosques->map(fn (Mosque $mosque) => [
            ...MosquePresenter::summary($mosque),
            'is_favorite' => $flags->has($mosque->id),
            'is_primary' => (bool) $flags->get($mosque->id, false),
            'today' => $times[$mosque->id]['today'] ?? null,
            'tomorrow' => $times[$mosque->id]['tomorrow'] ?? null,
        ])->values()->all();
    }

    /**
     * @param  EloquentCollection<int, Mosque>  $mosques
     * @return array<int, array{today: array<string, mixed>|null, tomorrow: array<string, mixed>|null}>
     */
    private static function todayAndTomorrow(EloquentCollection $mosques): array
    {
        [$publishing, $silent] = $mosques->partition(fn (Mosque $m) => (int) ($m->calendars_count ?? 0) > 0);
        $times = PublishedToday::for($publishing);
        $calculated = app(CalculatedTimes::class);
        $lite = fn (array $day) => ['date' => $day['date'], 'times' => $day['times'], 'source' => MosqueTimetable::SOURCE_CALCULATED];
        foreach ($silent as $mosque) {
            $now = CarbonImmutable::now($mosque->timezone);
            $times[$mosque->id] = [
                'today' => $lite($calculated->mosqueDay($mosque, $now)),
                'tomorrow' => $lite($calculated->mosqueDay($mosque, $now->addDay())),
            ];
        }

        return $times;
    }

    /**
     * The user's saved mosques, their own mosque first, then by name.
     *
     * @return EloquentCollection<int, Mosque>
     */
    public static function favoritesOf(User $user): EloquentCollection
    {
        /** @var EloquentCollection<int, Mosque> $mosques */
        $mosques = $user->favoriteMosques()
            ->withCount('calendars')
            ->orderByDesc('favorite_mosques.is_primary')
            ->orderBy('mosques.name')
            ->limit(FavoriteMosqueController::MAX)
            ->get();

        return $mosques;
    }

    /**
     * mosque id → is_primary, for the mosques of this list the user saved (one query).
     *
     * @param  EloquentCollection<int, Mosque>  $mosques
     * @return Collection<int, bool>
     */
    public static function favoriteFlags(EloquentCollection $mosques, ?User $user): Collection
    {
        if (! $user || $mosques->isEmpty()) {
            return collect();
        }

        return DB::table('favorite_mosques')
            ->where('user_id', $user->id)
            ->whereIn('mosque_id', $mosques->modelKeys())
            ->pluck('is_primary', 'mosque_id')
            ->map(fn ($primary) => (bool) $primary);
    }
}
