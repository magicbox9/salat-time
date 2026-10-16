<?php

namespace App\Services\Geocoding;

/** The one place shape every geocoding provider returns. */
final class Place
{
    /** address = a numbered house, street, city (town / village), postcode, region, place (anything else). */
    public const KINDS = ['address', 'street', 'city', 'postcode', 'region', 'place'];

    /** @return array{label: string, lat: float, lng: float, city: string|null, postcode: string|null, country: string, kind: string} */
    public static function make(
        string $label,
        float $lat,
        float $lng,
        ?string $city,
        ?string $postcode,
        string $country,
        string $kind,
    ): array {
        return [
            'label' => mb_substr(trim($label), 0, 200),
            'lat' => round($lat, 6),
            'lng' => round($lng, 6),
            'city' => self::clean($city, 120),
            'postcode' => self::clean($postcode, 16),
            'country' => strtoupper(substr($country, 0, 2)),
            'kind' => in_array($kind, self::KINDS, true) ? $kind : 'place',
        ];
    }

    /**
     * Coordinates a provider sent back, or null when they are not usable.
     *
     * @return array{0: float, 1: float}|null
     */
    public static function coordinates(mixed $lat, mixed $lng): ?array
    {
        if (! is_numeric($lat) || ! is_numeric($lng)) {
            return null;
        }
        $lat = (float) $lat;
        $lng = (float) $lng;

        return $lat >= -90 && $lat <= 90 && $lng >= -180 && $lng <= 180 ? [$lat, $lng] : null;
    }

    private static function clean(mixed $value, int $max): ?string
    {
        if (! is_string($value) || trim($value) === '') {
            return null;
        }

        return mb_substr(trim($value), 0, $max);
    }
}
