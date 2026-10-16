<?php

namespace App\Support;

use App\Models\Mosque;

/** The mosque fields every page and map can rely on. */
class MosquePresenter
{
    /** @return array<string, mixed> */
    public static function summary(Mosque $mosque): array
    {
        return [
            'id' => $mosque->id,
            'slug' => $mosque->slug,
            'name' => $mosque->name,
            'address' => $mosque->address,
            'postcode' => $mosque->postcode,
            'city' => $mosque->city,
            'country_code' => $mosque->country_code,
            'lat' => $mosque->latitude,
            'lng' => $mosque->longitude,
            'timezone' => $mosque->timezone,
            'distance_m' => isset($mosque->distance_m) ? (int) round((float) $mosque->distance_m) : null,
            'has_times' => isset($mosque->calendars_count) ? $mosque->calendars_count > 0 : $mosque->source === 'mawaqit',
            'verified' => $mosque->verified_at !== null,
            'source' => $mosque->source,
            'logo_url' => $mosque->logo_path ? asset('storage/'.$mosque->logo_path) : null,
            'mawaqit_url' => $mosque->mawaqitUrl(),
            'google_maps_url' => $mosque->googleMapsUrl(),
        ];
    }
}
