<?php

namespace App\Http\Controllers\Discover;

use App\Http\Controllers\Controller;
use App\Models\Mosque;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\ValidationException;

/**
 * GET /mosques/in-bounds.json?w&s&e&n → every mosque in the visible map area
 * (small dots once the map is zoomed in). The box is limited to about 2° × 2°
 * and the answer to 500 mosques, with only the fields a dot needs.
 */
class MosquesInBoundsController extends Controller
{
    public const MAX_SPAN = 2.0;

    public const MAX_ROWS = 500;

    public function __invoke(Request $request): JsonResponse
    {
        $data = $request->validate([
            'w' => ['required', 'numeric', 'between:-180,180'],
            'e' => ['required', 'numeric', 'between:-180,180'],
            's' => ['required', 'numeric', 'between:-90,90'],
            'n' => ['required', 'numeric', 'between:-90,90'],
        ]);
        [$w, $e, $s, $n] = [(float) $data['w'], (float) $data['e'], (float) $data['s'], (float) $data['n']];

        // A box may cross the antimeridian (west edge east of the east edge).
        $crosses = $w > $e;
        $lngSpan = $crosses ? $e + 360 - $w : $e - $w;
        if ($n <= $s || $n - $s > self::MAX_SPAN || $lngSpan > self::MAX_SPAN) {
            throw ValidationException::withMessages(['bounds' => ui('discover.bounds_too_large')]);
        }

        // The earthdistance index finds candidates around the box centre; the
        // exact box is then applied to latitude and longitude.
        $centerLat = ($s + $n) / 2;
        $centerLng = $w + $lngSpan / 2;
        $centerLng = $centerLng > 180 ? $centerLng - 360 : $centerLng;
        $radius = max(
            self::metres($centerLat, $centerLng, $n, $w + $lngSpan),
            self::metres($centerLat, $centerLng, $s, $w + $lngSpan),
        ) * 1.05 + 100;

        $rows = Mosque::query()
            ->select(['id', 'slug', 'name', 'city', 'latitude', 'longitude'])
            ->withExists('calendars')
            ->whereRaw('earth_box(ll_to_earth(?, ?), ?) @> ll_to_earth(latitude::float8, longitude::float8)', [$centerLat, $centerLng, $radius])
            ->whereBetween('latitude', [$s, $n])
            ->where(fn ($q) => $crosses
                ? $q->where('longitude', '>=', $w)->orWhere('longitude', '<=', $e)
                : $q->whereBetween('longitude', [$w, $e]))
            // When the area holds too many, keep the mosques that publish times.
            ->orderByDesc('calendars_exists')
            ->orderBy('id')
            ->limit(self::MAX_ROWS + 1)
            ->get();

        return response()->json([
            'truncated' => $rows->count() > self::MAX_ROWS,
            'mosques' => $rows->take(self::MAX_ROWS)->map(fn (Mosque $m) => [
                'id' => $m->id,
                'slug' => $m->slug,
                'name' => $m->name,
                'city' => $m->city,
                'lat' => $m->latitude,
                'lng' => $m->longitude,
                'has_times' => (bool) $m->getAttribute('calendars_exists'),
            ])->values(),
        ]);
    }

    /** Great-circle distance in metres (centre to corner, for the index search). */
    private static function metres(float $lat1, float $lng1, float $lat2, float $lng2): float
    {
        $rad = M_PI / 180;
        $a = sin(($lat2 - $lat1) * $rad / 2) ** 2
            + cos($lat1 * $rad) * cos($lat2 * $rad) * sin(($lng2 - $lng1) * $rad / 2) ** 2;

        return 2 * 6371000 * asin(min(1, sqrt($a)));
    }
}
