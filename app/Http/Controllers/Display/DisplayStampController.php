<?php

namespace App\Http\Controllers\Display;

use App\Http\Controllers\Controller;
use App\Models\Mosque;
use App\Services\Display\DisplayPayload;
use Illuminate\Http\JsonResponse;

/**
 * GET /mosques/{slug}/display/stamp.json → { stamp }: asked by every screen
 * once a minute. When it differs from the stamp of the screen's data, the
 * screen fetches display.json again — so a manager's change or a message
 * that starts shows within a minute, without downloading the week each time.
 */
class DisplayStampController extends Controller
{
    public function __invoke(Mosque $mosque, DisplayPayload $payload): JsonResponse
    {
        return response()
            ->json(['stamp' => $payload->stamp($mosque)])
            ->header('Cache-Control', 'no-store');
    }
}
