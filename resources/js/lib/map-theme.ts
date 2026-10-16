import type { Map as MapLibreMap } from 'maplibre-gl';

/**
 * OpenFreeMap's dark style paints land and sea almost black, so the globe
 * disappears against the night sky. Give them the app's deep night colours.
 */
export function tintDarkStyle(map: MapLibreMap): void {
    const paint: [string, string, string][] = [
        ['background', 'background-color', '#15322c'],
        ['water', 'fill-color', '#0c2d40'],
        ['landuse_park', 'fill-color', '#1b3b33'],
        ['landcover_wood', 'fill-color', '#1b3b33'],
    ];

    for (const [layer, property, value] of paint) {
        if (map.getLayer(layer)) {
            map.setPaintProperty(layer, property, value);
        }
    }
}
