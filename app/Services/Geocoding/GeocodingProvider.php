<?php

namespace App\Services\Geocoding;

/**
 * Turns "city, postcode or address" into places.
 *
 * Every provider returns the same normalised shape:
 * list<array{label: string, lat: float, lng: float, city: string|null,
 *            postcode: string|null, country: string, kind: string}>
 * where kind is one of Place::KINDS.
 */
interface GeocodingProvider
{
    /** Short identifier stored with cached answers ("ban", "nominatim"). */
    public function name(): string;

    /** Whether answers depend on the interface language (part of the cache key). */
    public function localized(): bool;

    /**
     * @return list<array<string, mixed>>
     *
     * @throws GeocodingUnavailable when the provider cannot answer right now
     */
    public function search(string $query, string $country, string $locale, int $limit): array;
}
