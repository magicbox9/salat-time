<?php

namespace App\Services\Geocoding;

use App\Models\GeocodeCache;
use App\Services\Geocoding\Providers\FrenchAddressProvider;
use App\Services\Geocoding\Providers\NominatimProvider;
use Illuminate\Support\Str;

/**
 * "City, postcode or address" → places, from the right provider for the
 * country, each distinct question looked up at most once a month
 * (geocode_cache).
 */
class GeocodingService
{
    public const CACHE_DAYS = 30;

    public const LIMIT = 6;

    public function __construct(
        private readonly FrenchAddressProvider $france,
        private readonly NominatimProvider $nominatim,
    ) {}

    public function providerFor(string $country): GeocodingProvider
    {
        return in_array(strtoupper($country), FrenchAddressProvider::COUNTRIES, true) ? $this->france : $this->nominatim;
    }

    /**
     * @return list<array<string, mixed>> places in the Place::make() shape
     *
     * @throws GeocodingUnavailable
     */
    public function search(string $query, string $country, string $locale = 'en'): array
    {
        $query = Str::of($query)->squish()->limit(200, '')->toString();
        $country = strtoupper($country);
        $provider = $this->providerFor($country);
        $hash = hash('sha256', implode('|', [
            $provider->name(),
            $country,
            $provider->localized() ? $locale : '',
            self::LIMIT,
            mb_strtolower($query),
        ]));

        $cached = GeocodeCache::query()
            ->where('query_hash', $hash)
            ->where('updated_at', '>=', now()->subDays(self::CACHE_DAYS))
            ->first();
        if ($cached) {
            /** @var list<array<string, mixed>> $results */
            $results = $cached->results;

            return $results;
        }

        $results = $provider->search($query, $country, $locale, self::LIMIT);
        $this->remember($hash, $query, $provider->name(), $results);

        return $results;
    }

    /**
     * Insert or refresh in one atomic statement (parallel requests for the
     * same question cannot collide; an expired answer gets a new updated_at).
     *
     * @param  list<array<string, mixed>>  $results
     */
    private function remember(string $hash, string $query, string $provider, array $results): void
    {
        GeocodeCache::query()->upsert([[
            'query_hash' => $hash,
            'query' => mb_substr($query, 0, 300),
            'provider' => $provider,
            'results' => json_encode($results, JSON_UNESCAPED_UNICODE | JSON_THROW_ON_ERROR),
        ]], ['query_hash'], ['query', 'provider', 'results']);
    }
}
