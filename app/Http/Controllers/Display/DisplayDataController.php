<?php

namespace App\Http\Controllers\Display;

use App\Http\Controllers\Controller;
use App\Models\Mosque;
use App\Services\Display\DisplayPayload;
use Illuminate\Http\JsonResponse;

/** GET /mosques/{slug}/display.json — everything a screen needs for a week (public, cached a minute). */
class DisplayDataController extends Controller
{
    public function __invoke(Mosque $mosque, DisplayPayload $payload): JsonResponse
    {
        $seconds = (int) config('display.cache_seconds', 60);

        return response()
            ->json($payload->cached($mosque))
            ->header('Cache-Control', "private, max-age=$seconds");
    }
}
