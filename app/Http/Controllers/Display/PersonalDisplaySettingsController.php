<?php

namespace App\Http\Controllers\Display;

use App\Http\Controllers\Controller;
use App\Http\Controllers\Display\Support\DisplayOptions;
use App\Models\User;
use App\Services\Display\DisplayPayload;
use App\Services\Display\DisplaySettings;
use App\Support\ChosenMosque;
use App\Support\MosquePresenter;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Inertia\Inertia;
use Inertia\Response;

/**
 * GET/PUT /display/settings — a person's own screen. Signed-in users keep
 * their choices in users.preferences.display; guests keep the same object
 * in this browser (the page saves it in localStorage).
 */
class PersonalDisplaySettingsController extends Controller
{
    public function edit(Request $request, DisplayPayload $payload): Response
    {
        $mosque = ChosenMosque::for($request);
        $user = $request->user();

        return Inertia::render('display/personal-settings', [
            'mosque' => $mosque ? MosquePresenter::summary($mosque) : null,
            'payload' => $mosque ? $payload->cached($mosque) : null,
            'settings' => $user ? DisplaySettings::forUser($user) : null,
            'options' => DisplayOptions::all(DisplaySettings::PERSONAL),
            'signedIn' => $user !== null,
        ]);
    }

    public function update(Request $request): JsonResponse|RedirectResponse
    {
        /** @var User $user */
        $user = $request->user();
        $values = $request->validate(DisplaySettings::rules(DisplaySettings::PERSONAL));
        $settings = DisplaySettings::saveForUser($user, $values);

        if ($request->expectsJson() && ! $request->header('X-Inertia')) {
            return response()->json(['settings' => $settings]);
        }

        return Inertia::flash('toast', ['type' => 'success', 'message' => ui('display.saved')])->back();
    }
}
