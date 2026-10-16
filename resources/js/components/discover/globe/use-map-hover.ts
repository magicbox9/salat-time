import type { Map as MapLibreMap, MapMouseEvent } from 'maplibre-gl';
import type { RefObject } from 'react';
import { useEffect } from 'react';
import { CLICKABLE } from './layers';

/**
 * Pointer feedback over mosque points: the point grows (feature-state
 * "hover"), the cursor becomes a hand, and a small tooltip shows the
 * mosque's name (set as plain text, never as HTML).
 */
export function useMapHover(
    mapRef: RefObject<MapLibreMap | null>,
    tooltipRef: RefObject<HTMLDivElement | null>,
    styleVersion: number,
    callbacks: RefObject<{ nameOf: (id: number) => string | null }>,
): void {
    useEffect(() => {
        const map = mapRef.current;

        if (!map || !styleVersion) {
            return;
        }

        let hovered: { source: string; id: number } | null = null;

        const clear = () => {
            // On unmount the map may already be removed (its style is gone and
            // getSource would throw): only touch it while it is still the map.
            if (
                hovered &&
                mapRef.current === map &&
                map.getSource(hovered.source)
            ) {
                map.setFeatureState(hovered, { hover: false });
            }

            hovered = null;
            map.getCanvas().style.cursor = '';

            if (tooltipRef.current) {
                tooltipRef.current.style.display = 'none';
            }
        };

        const move = (event: MapMouseEvent) => {
            const layers = CLICKABLE.filter((id) => map.getLayer(id));
            const feature = map.queryRenderedFeatures(event.point, {
                layers,
            })[0];
            const id = Number(feature?.properties?.id);

            if (!feature || !id) {
                clear();

                return;
            }

            if (
                !hovered ||
                hovered.id !== id ||
                hovered.source !== feature.source
            ) {
                clear();
                hovered = { source: feature.source, id };
                map.setFeatureState(hovered, { hover: true });
            }

            map.getCanvas().style.cursor = 'pointer';
            const name = callbacks.current.nameOf(id);
            const element = tooltipRef.current;

            if (element && name) {
                element.textContent = name;
                element.style.display = 'block';
                element.style.transform = `translate(${event.point.x + 14}px, ${event.point.y + 14}px)`;
            }
        };

        map.on('mousemove', move);
        map.on('mouseout', clear);

        return () => {
            map.off('mousemove', move);
            map.off('mouseout', clear);
            clear();
        };
    }, [mapRef, tooltipRef, styleVersion, callbacks]);
}
