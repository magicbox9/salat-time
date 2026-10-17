<?php

namespace App\Http\Controllers\Display;

use App\Http\Controllers\Controller;
use App\Http\Controllers\Display\Support\DisplayOptions;
use App\Http\Controllers\Display\Support\MessagePresenter;
use App\Models\Mosque;
use App\Models\User;
use App\Services\Display\AdhanCatalog;
use App\Services\Display\DisplayPayload;
use App\Services\Display\DisplaySettings;
use App\Support\MosquePresenter;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Inertia\Inertia;
use Inertia\Response;

/**
 * GET/PUT /manage/{slug}/display — how the mosque's screen looks and behaves
 * (MosquePolicy@manage, checked by the route). Only known keys are saved.
 */
class MosqueDisplaySettingsController extends Controller
{
    public function edit(Mosque $mosque, DisplayPayload $payload, AdhanCatalog $catalog): Response
    {
        $mosque->load('displaySetting');
        $row = $mosque->displaySetting;

        return Inertia::render('display/settings', [
            'mosque' => MosquePresenter::summary($mosque),
            'settings' => DisplaySettings::forMosque($mosque),
            'options' => DisplayOptions::all(DisplaySettings::MOSQUE),
            'messages' => MessagePresenter::all($mosque),
            // The live preview runs on fresh data (not the minute-long cache).
            'payload' => $payload->build($mosque),
            'backgroundUrl' => $row?->background_path ? asset('storage/'.$row->background_path) : null,
            'ownAdhan' => $catalog->mosqueTrack($mosque),
            'screenUrl' => url("/mosques/{$mosque->slug}/display"),
        ]);
    }

    public function update(Request $request, Mosque $mosque): RedirectResponse
    {
        /** @var User $user */
        $user = $request->user();
        $values = $request->validate(DisplaySettings::rules(DisplaySettings::MOSQUE));
        DisplaySettings::saveForMosque($mosque, $values, $user);
        DisplayPayload::forget($mosque);

        return Inertia::flash('toast', ['type' => 'success', 'message' => ui('display.saved')])->back();
    }
}
