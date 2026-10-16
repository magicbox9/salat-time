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
use Inertia\Inertia;

/**
 * Save / remove a mosque from the signed-in user's mosques. Always about the
 * user's own list (the user comes from the session, never from the request).
 * Answers JSON to fetch() calls and redirects back with a toast otherwise.
 */
class FavoriteMosqueController extends Controller
{
    /** Saved mosques per account. */
    public const MAX = 100;

    public function store(Request $request, Mosque $mosque): JsonResponse|RedirectResponse
    {
        /** @var User $user */
        $user = $request->user();
        $saved = $user->favoriteMosques()->whereKey($mosque->id)->exists();

        if (! $saved) {
            if ($user->favoriteMosques()->count() >= self::MAX) {
                throw ValidationException::withMessages(['mosque' => ui('discover.favorites_full', ['max' => self::MAX])]);
            }
            // Saving twice (double click, two tabs) keeps a single row.
            DB::table('favorite_mosques')->insertOrIgnore([
                'user_id' => $user->id,
                'mosque_id' => $mosque->id,
                'is_primary' => false,
                'created_at' => now(),
                'updated_at' => now(),
            ]);
        }

        return self::answer($request, $user, $mosque, $saved ? 'discover.favorite_already' : 'discover.favorite_added');
    }

    public function destroy(Request $request, Mosque $mosque): JsonResponse|RedirectResponse
    {
        /** @var User $user */
        $user = $request->user();
        $user->favoriteMosques()->detach($mosque->id);

        return self::answer($request, $user, $mosque, 'discover.favorite_removed');
    }

    /** The mosque's state for this user after the change. */
    public static function answer(Request $request, User $user, Mosque $mosque, string $message): JsonResponse|RedirectResponse
    {
        $primary = DB::table('favorite_mosques')->where('user_id', $user->id)->where('mosque_id', $mosque->id)->value('is_primary');
        $state = [
            'slug' => $mosque->slug,
            'is_favorite' => $primary !== null,
            'is_primary' => (bool) $primary,
            'message' => ui($message, ['name' => $mosque->name]),
        ];

        if ($request->expectsJson() && ! $request->header('X-Inertia')) {
            return response()->json($state);
        }

        Inertia::flash('toast', ['type' => 'success', 'message' => $state['message']]);

        return back();
    }
}
