<?php

namespace App\Http\Controllers\Display;

use App\Http\Controllers\Controller;
use App\Models\Mosque;
use App\Services\Display\DisplayPayload;
use App\Services\Display\DisplaySettings;
use App\Support\ChosenMosque;
use Illuminate\Http\Request;
use Inertia\Inertia;
use Inertia\Response;

/**
 * The full-screen display: a mosque's own screen (its settings) and the
 * visitor's personal screen at /display (their chosen mosque, their own
 * settings: the account's, or this browser's for guests).
 */
class DisplayScreenController extends Controller
{
    public function mosque(Request $request, Mosque $mosque, DisplayPayload $payload): Response
    {
        $canManage = $request->user()?->can('manage', $mosque) ?? false;

        return Inertia::render('display/screen', [
            'mode' => 'mosque',
            'payload' => $payload->cached($mosque),
            'personal' => null,
            'signedIn' => $request->user() !== null,
            'settingsUrl' => $canManage ? "/manage/{$mosque->slug}/display" : null,
        ]);
    }

    public function personal(Request $request, DisplayPayload $payload): Response
    {
        $mosque = ChosenMosque::for($request);
        $user = $request->user();

        return Inertia::render('display/screen', [
            'mode' => 'personal',
            'payload' => $mosque ? $payload->cached($mosque) : null,
            'personal' => $user ? DisplaySettings::forUser($user) : null,
            'personalDefaults' => DisplaySettings::merged([], DisplaySettings::PERSONAL),
            'signedIn' => $user !== null,
            'settingsUrl' => '/display/settings',
        ]);
    }
}
