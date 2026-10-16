<?php

namespace App\Services\Geocoding\Providers;

use App\Services\Geocoding\GeocodingProvider;
use App\Services\Geocoding\GeocodingUnavailable;
use App\Services\Geocoding\Place;
use Illuminate\Http\Client\ConnectionException;
use Illuminate\Support\Facades\Http;

/**
 * The French national address base (BAN), free and without a key. It covers
 * metropolitan France and the overseas departments. The service moved from
 * api-adresse.data.gouv.fr to the Géoplateforme (same answers, same format);
 * the old host now redirects and is being decommissioned.
 */
class FrenchAddressProvider implements GeocodingProvider
{
    public const DEFAULT_URL = 'https://data.geopf.fr/geocodage/search/';

    /** Country codes the BAN answers for (France and its overseas departments). */
    public const COUNTRIES = ['FR', 'GP', 'MQ', 'GF', 'RE', 'YT', 'PM', 'BL', 'MF'];

    /** INSEE code prefix of each overseas territory. */
    private const OVERSEAS = ['971' => 'GP', '972' => 'MQ', '973' => 'GF', '974' => 'RE', '975' => 'PM', '976' => 'YT', '977' => 'BL', '978' => 'MF'];

    private const KINDS = ['housenumber' => 'address', 'street' => 'street', 'municipality' => 'city', 'locality' => 'place'];

    /** The BAN's largest page; an overseas search asks for it, then keeps that territory's places. */
    private const MAX_LIMIT = 50;

    public function name(): string
    {
        return 'ban';
    }

    public function localized(): bool
    {
        return false;
    }

    public function search(string $query, string $country, string $locale, int $limit): array
    {
        // The BAN refuses (400) text that does not start with a letter or a
        // digit, or that is shorter than 3 characters: no place, no request.
        $query = (string) preg_replace('/^[^\pL\pN]+/u', '', $query);
        if (mb_strlen($query) < 3) {
            return [];
        }

        // An overseas territory: only overseas places (department code 97…),
        // then only the chosen territory's, so "Saint-Pierre" chosen in
        // Réunion is not answered with a street in mainland France.
        $overseas = $country !== 'FR' && in_array($country, self::COUNTRIES, true);
        $params = ['q' => $query, 'limit' => $overseas ? self::MAX_LIMIT : $limit, 'autocomplete' => 1];
        if ($overseas) {
            $params['depcode'] = '97';
        }

        try {
            $response = Http::timeout(5)
                ->acceptJson()
                ->withUserAgent((string) config('services.geocoding.user_agent', NominatimProvider::DEFAULT_USER_AGENT))
                ->get((string) config('services.geocoding.ban_url', self::DEFAULT_URL), $params);
        } catch (ConnectionException $e) {
            throw new GeocodingUnavailable('BAN unreachable', previous: $e);
        }

        // A question the BAN cannot parse has no answer; it is not an outage.
        if ($response->status() === 400) {
            return [];
        }
        if (! $response->successful()) {
            throw new GeocodingUnavailable('BAN answered '.$response->status());
        }

        $places = [];
        foreach ((array) $response->json('features', []) as $feature) {
            $properties = (array) ($feature['properties'] ?? []);
            $point = Place::coordinates($feature['geometry']['coordinates'][1] ?? null, $feature['geometry']['coordinates'][0] ?? null);
            if (! $point || ! is_string($properties['label'] ?? null)) {
                continue;
            }
            $territory = $this->territory((string) ($properties['citycode'] ?? ''));
            if ($overseas && $territory !== $country) {
                continue;
            }
            $places[] = Place::make(
                $properties['label'],
                $point[0],
                $point[1],
                $properties['city'] ?? null,
                $properties['postcode'] ?? null,
                $territory,
                self::KINDS[$properties['type'] ?? ''] ?? 'place',
            );
        }

        return array_slice($places, 0, $limit);
    }

    private function territory(string $cityCode): string
    {
        return self::OVERSEAS[substr($cityCode, 0, 3)] ?? 'FR';
    }
}
