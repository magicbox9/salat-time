<?php

namespace App\Http\Controllers\Discover\Support;

use App\Http\Controllers\Discover\FavoriteMosqueController;
use App\Models\Mosque;
use App\Models\User;
use App\Support\MosquePresenter;
use Illuminate\Database\Eloquent\Collection as EloquentCollection;
use Illuminate\Support\Collection;
use Illuminate\Support\Facades\DB;

/**
 * Mosque summaries for maps and lists, plus whether the visitor saved each
 * one and (optionally) today's published times for the next-prayer countdown.
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
        $times = $withTimes
            ? PublishedToday::for($mosques->filter(fn (Mosque $m) => (int) ($m->calendars_count ?? 0) > 0))
            : [];

        return $mosques->map(fn (Mosque $mosque) => [
            ...MosquePresenter::summary($mosque),
            'is_favorite' => $flags->has($mosque->id),
            'is_primary' => (bool) $flags->get($mosque->id, false),
            'today' => $times[$mosque->id]['today'] ?? null,
            'tomorrow' => $times[$mosque->id]['tomorrow'] ?? null,
        ])->values()->all();
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
