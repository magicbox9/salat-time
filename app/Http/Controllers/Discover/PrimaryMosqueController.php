<?php

namespace App\Http\Controllers\Discover;

use App\Http\Controllers\Controller;
use App\Models\Mosque;
use App\Models\User;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

/**
 * "My mosque": one saved mosque marked as the user's own (the globe flies to
 * it on the next visit). Setting it saves the mosque first when needed and
 * clears the mark from every other saved mosque.
 */
class PrimaryMosqueController extends Controller
{
    public function store(Request $request, Mosque $mosque): JsonResponse|RedirectResponse
    {
        /** @var User $user */
        $user = $request->user();

        DB::transaction(function () use ($user, $mosque) {
            // Serialise concurrent changes for this user (one primary at most).
            DB::table('users')->where('id', $user->id)->lockForUpdate()->first();

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
        });

        return FavoriteMosqueController::answer($request, $user, $mosque, 'discover.primary_set');
    }

    public function destroy(Request $request, Mosque $mosque): JsonResponse|RedirectResponse
    {
        /** @var User $user */
        $user = $request->user();
        DB::table('favorite_mosques')
            ->where('user_id', $user->id)
            ->where('mosque_id', $mosque->id)
            ->update(['is_primary' => false, 'updated_at' => now()]);

        return FavoriteMosqueController::answer($request, $user, $mosque, 'discover.primary_unset');
    }
}
