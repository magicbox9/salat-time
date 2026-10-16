<?php

namespace App\Http\Controllers\Discover;

use App\Http\Controllers\Controller;
use App\Http\Controllers\Discover\Support\MyMosque;
use App\Models\Mosque;
use App\Models\User;
use App\Support\ChosenMosque;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Cookie;

/**
 * "My mosque" toggled from a saved mosque (/me/mosques). Setting it saves the
 * mosque first when needed and clears the mark from every other saved mosque;
 * the hub at "/" then opens on it. POST /my-mosque does the same from the
 * globe and also works for guests.
 */
class PrimaryMosqueController extends Controller
{
    public function store(Request $request, Mosque $mosque): JsonResponse|RedirectResponse
    {
        /** @var User $user */
        $user = $request->user();
        MyMosque::choose($user, $mosque);

        return FavoriteMosqueController::answer($request, $user, $mosque, 'discover.primary_set');
    }

    public function destroy(Request $request, Mosque $mosque): JsonResponse|RedirectResponse
    {
        /** @var User $user */
        $user = $request->user();
        MyMosque::clear($user, $mosque);
        // A guest choice left in this browser must not come back as "my mosque".
        Cookie::queue(ChosenMosque::forget());

        return FavoriteMosqueController::answer($request, $user, $mosque, 'discover.primary_unset');
    }
}
