import type {
    ExpressionSpecification,
    GeoJSONSource,
    Map as MapLibreMap,
} from 'maplibre-gl';
import type { MosquePin, Origin } from '../types';
import type { MapTheme } from './map-style';
import { DOTS_MIN_ZOOM, PALETTE } from './map-style';
import { PRIMARY_IMAGE, STAR_IMAGE } from './marker-images';

export const SOURCES = {
    bounds: 'discover-bounds',
    nearby: 'discover-nearby',
    favorites: 'discover-favorites',
    origin: 'discover-origin',
    selected: 'discover-selected',
} as const;

export const LAYERS = {
    bounds: 'discover-bounds-dots',
    nearby: 'discover-nearby-points',
    favorites: 'discover-favorites-icons',
    originHalo: 'discover-origin-halo',
    origin: 'discover-origin-point',
    selected: 'discover-selected-ring',
} as const;

/** Layers that open a mosque when clicked, topmost first. */
export const CLICKABLE = [LAYERS.favorites, LAYERS.nearby, LAYERS.bounds];

type PinProperties = { id: number; has_times: boolean; is_primary: boolean };
type Collection = GeoJSON.FeatureCollection<
    GeoJSON.Point,
    PinProperties | Record<string, never>
>;

const EMPTY: Collection = { type: 'FeatureCollection', features: [] };

const hovered = (
    whenHovered: number,
    otherwise: number,
): ExpressionSpecification => [
    'case',
    ['boolean', ['feature-state', 'hover'], false],
    whenHovered,
    otherwise,
];

export function pinsToCollection(pins: MosquePin[]): Collection {
    return {
        type: 'FeatureCollection',
        features: pins.map((pin) => ({
            type: 'Feature',
            id: pin.id,
            geometry: { type: 'Point', coordinates: [pin.lng, pin.lat] },
            properties: {
                id: pin.id,
                has_times: pin.has_times,
                is_primary: Boolean(pin.is_primary),
            },
        })),
    };
}

export function pointCollection(
    point: { lat: number; lng: number } | null,
): Collection {
    return point
        ? {
              type: 'FeatureCollection',
              features: [
                  {
                      type: 'Feature',
                      geometry: {
                          type: 'Point',
                          coordinates: [point.lng, point.lat],
                      },
                      properties: {},
                  },
              ],
          }
        : EMPTY;
}

export function setCollection(
    map: MapLibreMap,
    source: string,
    data: Collection,
): void {
    (map.getSource(source) as GeoJSONSource | undefined)?.setData(data);
}

export type OriginPoint = Pick<Origin, 'lat' | 'lng'> | null;

/** Sources and layers for the mosques, added on top of the base style after every style load. */
export function installLayers(map: MapLibreMap, theme: MapTheme): void {
    const colors = PALETTE[theme];
    const timesColor: ExpressionSpecification = [
        'case',
        ['get', 'has_times'],
        colors.times,
        colors.noTimes,
    ];

    for (const id of Object.values(SOURCES)) {
        if (!map.getSource(id)) {
            map.addSource(id, {
                type: 'geojson',
                data: EMPTY,
                promoteId: id === SOURCES.origin ? undefined : 'id',
            });
        }
    }

    map.addLayer({
        id: LAYERS.bounds,
        type: 'circle',
        source: SOURCES.bounds,
        minzoom: DOTS_MIN_ZOOM,
        paint: {
            'circle-color': timesColor,
            'circle-radius': [
                'interpolate',
                ['linear'],
                ['zoom'],
                9,
                hovered(5, 2.5),
                15,
                hovered(8, 5),
            ],
            'circle-stroke-color': colors.ring,
            'circle-stroke-width': 1,
            'circle-opacity': 0.85,
        },
    });
    map.addLayer({
        id: LAYERS.originHalo,
        type: 'circle',
        source: SOURCES.origin,
        paint: {
            'circle-color': colors.halo,
            'circle-opacity': 0.18,
            'circle-radius': 22,
            'circle-pitch-alignment': 'map',
        },
    });
    map.addLayer({
        id: LAYERS.origin,
        type: 'circle',
        source: SOURCES.origin,
        paint: {
            'circle-color': colors.ring,
            'circle-radius': 5,
            'circle-stroke-color': colors.gold,
            'circle-stroke-width': 3,
        },
    });
    map.addLayer({
        id: LAYERS.nearby,
        type: 'circle',
        source: SOURCES.nearby,
        paint: {
            'circle-color': timesColor,
            'circle-radius': [
                'interpolate',
                ['linear'],
                ['zoom'],
                3,
                hovered(6, 4),
                10,
                hovered(10, 7),
                16,
                hovered(13, 10),
            ],
            'circle-stroke-color': colors.ring,
            'circle-stroke-width': 2,
        },
    });
    map.addLayer({
        id: LAYERS.selected,
        type: 'circle',
        source: SOURCES.selected,
        paint: {
            'circle-color': 'rgba(0,0,0,0)',
            'circle-radius': [
                'interpolate',
                ['linear'],
                ['zoom'],
                3,
                10,
                16,
                18,
            ],
            'circle-stroke-color': colors.gold,
            'circle-stroke-width': 3,
        },
    });
    map.addLayer({
        id: LAYERS.favorites,
        type: 'symbol',
        source: SOURCES.favorites,
        layout: {
            'icon-image': [
                'case',
                ['get', 'is_primary'],
                PRIMARY_IMAGE,
                STAR_IMAGE,
            ],
            'icon-size': [
                'interpolate',
                ['linear'],
                ['zoom'],
                1,
                0.85,
                12,
                1.15,
            ],
            'icon-allow-overlap': true,
            'icon-ignore-placement': true,
            'symbol-sort-key': ['case', ['get', 'is_primary'], 1, 0],
        },
    });
}
