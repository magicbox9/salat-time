<?php

namespace App\Support;

/**
 * Whether an OpenStreetMap object tagged religion=muslim is a mosque or
 * prayer hall. The study's OSM list also holds Muslim funeral directors,
 * bookshops, butchers, travel agencies, schools, offices and cemetery plots;
 * none of them belongs on the map of mosques.
 */
final class OsmPlaceOfWorship
{
    /** Tags that say the object is something else, even on a "mosque" building. */
    private const OTHER_USES = ['shop', 'office', 'amenity', 'landuse', 'craft', 'healthcare', 'tourism'];

    /** @param  array<string, mixed>  $tags */
    public static function accepts(array $tags): bool
    {
        if (($tags['amenity'] ?? null) === 'place_of_worship') {
            return true;
        }
        if (($tags['building'] ?? null) !== 'mosque') {
            return false;
        }
        foreach (self::OTHER_USES as $key) {
            if (isset($tags[$key])) {
                return false;
            }
        }

        return true;
    }
}
