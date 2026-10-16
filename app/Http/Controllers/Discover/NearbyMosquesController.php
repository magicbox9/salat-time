<?php

namespace App\Http\Controllers\Discover;

use App\Http\Controllers\Controller;
use App\Http\Controllers\Discover\Support\MosqueCards;
use App\Models\Mosque;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

/**
 * GET /mosques/near.json?lat&lng[&radius][&limit] → the nearest mosques.
 *
 * Without a radius the search widens 5 → 10 → 25 → 50 km until it finds
 * enough mosques, in a single query (the nearest ones within 50 km, then
 * trimmed to the smallest step that holds enough of them).
 */
class NearbyMosquesController extends Controller
{
    /** @var list<int> */
    public const STEPS_KM = [5, 10, 25, 50];

    public const ENOUGH = 8;

    public const DEFAULT_LIMIT = 30;

    public function __invoke(Request $request): JsonResponse
    {
        $data = $request->validate([
            'lat' => ['required', 'numeric', 'between:-90,90'],
            'lng' => ['required', 'numeric', 'between:-180,180'],
            'radius' => ['nullable', 'numeric', 'between:1,50'],
            'limit' => ['nullable', 'integer', 'between:1,50'],
        ]);
        $lat = (float) $data['lat'];
        $lng = (float) $data['lng'];
        $limit = (int) ($data['limit'] ?? self::DEFAULT_LIMIT);
        $fixed = isset($data['radius']);
        $radius = $fixed ? (float) $data['radius'] : (float) max(self::STEPS_KM);

        $mosques = Mosque::near($lat, $lng, $radius)->withCount('calendars')->limit($limit)->get();

        if (! $fixed) {
            $wanted = min(self::ENOUGH, $limit);
            foreach (self::STEPS_KM as $step) {
                if ($mosques->filter(fn (Mosque $m) => self::distance($m) <= $step * 1000)->count() >= $wanted) {
                    $radius = (float) $step;
                    break;
                }
            }
            $mosques = $mosques->filter(fn (Mosque $m) => self::distance($m) <= $radius * 1000)->values();
        }

        return response()->json([
            'origin' => ['lat' => $lat, 'lng' => $lng],
            'radius_km' => $radius,
            'mosques' => MosqueCards::make($mosques, $request->user()),
        ]);
    }

    /** Metres from the search point (added by the near() scope). */
    private static function distance(Mosque $mosque): float
    {
        return (float) $mosque->getAttribute('distance_m');
    }
}
