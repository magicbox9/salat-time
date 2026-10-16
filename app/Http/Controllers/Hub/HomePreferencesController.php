<?php

namespace App\Http\Controllers\Hub;

use App\Http\Controllers\Controller;
use App\Http\Controllers\Hub\Support\HubPreferences;
use App\Models\User;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;

/**
 * PATCH /me/preferences/home — the signed-in user's hub display choices
 * (style, iqama, seconds, 12/24 h, Hijri, compact, adhan). Only known keys
 * are validated and merged; anything else in the request is ignored.
 */
class HomePreferencesController extends Controller
{
    public function __invoke(Request $request): JsonResponse|RedirectResponse
    {
        /** @var User $user */
        $user = $request->user();
        $values = $request->validate(HubPreferences::rules());
        $preferences = HubPreferences::merge($user, $values);

        if ($request->expectsJson() && ! $request->header('X-Inertia')) {
            return response()->json(['preferences' => $preferences]);
        }

        return back();
    }
}
