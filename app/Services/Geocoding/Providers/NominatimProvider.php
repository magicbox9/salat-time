<?php

namespace App\Services\Geocoding\Providers;

use App\Services\Geocoding\GeocodingProvider;
use App\Services\Geocoding\GeocodingUnavailable;
use App\Services\Geocoding\Place;
use Illuminate\Contracts\Cache\LockTimeoutException;
use Illuminate\Http\Client\ConnectionException;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Http;

/**
 * OpenStreetMap's Nominatim for every country outside the BAN. Its usage
 * policy allows at most one request per second from the whole application,
 * an identifying User-Agent, and no search-as-you-type: the page only sends
 * a query when the visitor presses Enter, and answers are cached for 30 days.
 */
class NominatimProvider implements GeocodingProvider
{
    public const DEFAULT_URL = 'https://nominatim.openstreetmap.org/search';

    public const DEFAULT_USER_AGENT = 'SalatTimeWeb/0.1 (local development)';

    /** Shared by every PHP worker (Redis in production): one request per second. */
    public const LOCK = 'geocoding:nominatim';

    private const KINDS = [
        'house' => 'address', 'building' => 'address', 'amenity' => 'address',
        'road' => 'street',
        'city' => 'city', 'town' => 'city', 'village' => 'city', 'municipality' => 'city', 'hamlet' => 'city',
        'postcode' => 'postcode',
        'state' => 'region', 'region' => 'region', 'province' => 'region', 'county' => 'region', 'country' => 'region',
    ];

    public function name(): string
    {
        return 'nominatim';
    }

    public function localized(): bool
    {
        return true;
    }

    public function search(string $query, string $country, string $locale, int $limit): array
    {
        try {
            // Wait (up to 3 s) for our turn; the lock is never released and
            // expires after one second, which spaces requests one second apart.
            Cache::lock(self::LOCK, 1)->block(3);
        } catch (LockTimeoutException $e) {
            throw new GeocodingUnavailable('Nominatim busy', previous: $e);
        }

        try {
            $response = Http::timeout(6)
                ->acceptJson()
                ->withUserAgent((string) config('services.geocoding.user_agent', self::DEFAULT_USER_AGENT))
                ->get((string) config('services.geocoding.nominatim_url', self::DEFAULT_URL), [
                    'format' => 'jsonv2',
                    'q' => $query,
                    'countrycodes' => strtolower($country),
                    'limit' => $limit,
                    'addressdetails' => 1,
                    'accept-language' => $locale,
                ]);
        } catch (ConnectionException $e) {
            throw new GeocodingUnavailable('Nominatim unreachable', previous: $e);
        }

        if (! $response->successful()) {
            throw new GeocodingUnavailable('Nominatim answered '.$response->status());
        }

        $places = [];
        foreach ((array) $response->json() as $item) {
            if (! is_array($item) || ! is_string($item['display_name'] ?? null)) {
                continue;
            }
            $point = Place::coordinates($item['lat'] ?? null, $item['lon'] ?? null);
            if (! $point) {
                continue;
            }
            $address = (array) ($item['address'] ?? []);
            $places[] = Place::make(
                $this->label($item['display_name']),
                $point[0],
                $point[1],
                $address['city'] ?? $address['town'] ?? $address['village'] ?? $address['municipality'] ?? null,
                $address['postcode'] ?? null,
                is_string($address['country_code'] ?? null) ? $address['country_code'] : $country,
                self::KINDS[$item['addresstype'] ?? ''] ?? 'place',
            );
        }

        return array_slice($places, 0, $limit);
    }

    /** "12, Rue X, Quartier, Ville, Région, 1000, Pays" → its first three parts. */
    private function label(string $displayName): string
    {
        return implode(', ', array_slice(array_map('trim', explode(',', $displayName)), 0, 3));
    }
}
