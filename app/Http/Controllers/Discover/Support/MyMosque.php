<?php

namespace App\Http\Controllers\Discover\Support;

use App\Http\Controllers\Discover\FavoriteMosqueController;
use App\Models\Mosque;
use App\Models\User;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

/**
 * "My mosque" of a signed-in user: one saved mosque marked as primary.
 * Shared by the globe ("Make it my mosque"), /me/mosques and the adoption of
 * a guest's choice at sign-in, so the rules live in one place.
 */
class MyMosque
{
    /**
     * Makes $mosque the user's own mosque (saving it first when needed).
     * With $onlyIfNone, nothing changes when the user already has one.
     *
     * @return bool whether the mosque is now the user's own mosque
     *
     * @throws ValidationException when the user's saved list is full
     */
    public static function choose(User $user, Mosque $mosque, bool $onlyIfNone = false): bool
    {
        return DB::transaction(function () use ($user, $mosque, $onlyIfNone): bool {
            // Serialise concurrent changes for this user (one primary at most).
            DB::table('users')->where('id', $user->id)->lockForUpdate()->first();

            if ($onlyIfNone && DB::table('favorite_mosques')->where('user_id', $user->id)->where('is_primary', true)->exists()) {
                return false;
            }

            $saved = DB::table('favorite_mosques')->where('user_id', $user->id)->where('mosque_id', $mosque->id)->exists();
            if (! $saved && $user->favoriteMosques()->count() >= FavoriteMosqueController::MAX) {
                throw ValidationException::withMessages(['mosque' => ui('discover.favorites_full', ['max' => FavoriteMosqueController::MAX])]);
            }

            // Clear the others first: the database allows one primary per user.
            DB::table('favorite_mosques')
                ->where('user_id', $user->id)
                ->where('mosque_id', '!=', $mosque->id)
                ->where('is_primary', true)
                ->update(['is_primary' => false, 'updated_at' => now()]);

            DB::table('favorite_mosques')->upsert(
                [['user_id' => $user->id, 'mosque_id' => $mosque->id, 'is_primary' => true, 'created_at' => now(), 'updated_at' => now()]],
                ['user_id', 'mosque_id'],
                ['is_primary', 'updated_at'],
            );

            return true;
        });
    }

    /** The user no longer has an own mosque (their saved mosques stay saved). */
    public static function clear(User $user, ?Mosque $only = null): void
    {
        DB::table('favorite_mosques')
            ->where('user_id', $user->id)
            ->when($only, fn ($q) => $q->where('mosque_id', $only->id))
            ->where('is_primary', true)
            ->update(['is_primary' => false, 'updated_at' => now()]);
    }

    /** The user's own mosque, if any. */
    public static function of(User $user): ?Mosque
    {
        /** @var Mosque|null $mosque */
        $mosque = $user->favoriteMosques()->wherePivot('is_primary', true)->first();

        return $mosque;
    }
}
