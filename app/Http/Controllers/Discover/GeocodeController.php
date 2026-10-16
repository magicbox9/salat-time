<?php

namespace App\Http\Controllers\Discover;

use App\Http\Controllers\Controller;
use App\Services\Geocoding\GeocodingService;
use App\Services\Geocoding\GeocodingUnavailable;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

/** GET /geocode.json?q=…&country=FR → places for the search card. */
class GeocodeController extends Controller
{
    public function __invoke(Request $request, GeocodingService $geocoder): JsonResponse
    {
        $data = $request->validate([
            'q' => ['required', 'string', 'min:3', 'max:200'],
            'country' => ['nullable', 'string', 'size:2', 'alpha:ascii'],
        ]);

        try {
            $results = $geocoder->search($data['q'], strtoupper($data['country'] ?? HomeController::INITIAL_COUNTRY), app()->getLocale());
        } catch (GeocodingUnavailable $e) {
            report($e);

            return response()->json(['message' => ui('discover.geocode_unavailable'), 'results' => []], 503);
        }

        return response()->json(['results' => $results]);
    }
}
