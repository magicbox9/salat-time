import type { Map as MapLibreMap } from 'maplibre-gl';
import type { RefObject } from 'react';
import { useEffect } from 'react';
import type { MosquePin } from '../types';
import type { OriginPoint } from './layers';
import {
    pinsToCollection,
    pointCollection,
    setCollection,
    SOURCES,
} from './layers';

type Data = {
    nearby: MosquePin[];
    dots: MosquePin[];
    favorites: MosquePin[];
    origin: OriginPoint;
    selected: MosquePin | null;
    highlightId: number | null;
};

/**
 * Pushes the page's mosques into the map's GeoJSON sources. `styleVersion`
 * changes after every style load (first load, light/dark switch), when the
 * sources are new and empty, so everything is pushed again.
 */
export function useGlobeData(
    mapRef: RefObject<MapLibreMap | null>,
    styleVersion: number,
    { nearby, dots, favorites, origin, selected, highlightId }: Data,
): void {
    useEffect(() => {
        if (mapRef.current && styleVersion) {
            setCollection(
                mapRef.current,
                SOURCES.nearby,
                pinsToCollection(nearby),
            );
        }
    }, [mapRef, nearby, styleVersion]);

    useEffect(() => {
        if (mapRef.current && styleVersion) {
            setCollection(
                mapRef.current,
                SOURCES.bounds,
                pinsToCollection(dots),
            );
        }
    }, [mapRef, dots, styleVersion]);

    useEffect(() => {
        if (mapRef.current && styleVersion) {
            setCollection(
                mapRef.current,
                SOURCES.favorites,
                pinsToCollection(favorites),
            );
        }
    }, [mapRef, favorites, styleVersion]);

    useEffect(() => {
        if (mapRef.current && styleVersion) {
            setCollection(
                mapRef.current,
                SOURCES.origin,
                pointCollection(origin),
            );
        }
    }, [mapRef, origin, styleVersion]);

    useEffect(() => {
        if (mapRef.current && styleVersion) {
            setCollection(
                mapRef.current,
                SOURCES.selected,
                pointCollection(selected),
            );
        }
    }, [mapRef, selected, styleVersion]);

    // A card hovered in the list lights up its point on the map.
    useEffect(() => {
        const map = mapRef.current;

        if (
            !map ||
            !styleVersion ||
            highlightId === null ||
            !map.getSource(SOURCES.nearby)
        ) {
            return;
        }

        const target = { source: SOURCES.nearby, id: highlightId };
        map.setFeatureState(target, { hover: true });

        return () => {
            // On unmount the map is removed first (no style left: getSource
            // would throw), so only reset the point on the live map.
            if (mapRef.current === map && map.getSource(SOURCES.nearby)) {
                map.setFeatureState(target, { hover: false });
            }
        };
    }, [mapRef, highlightId, nearby, styleVersion]);
}
