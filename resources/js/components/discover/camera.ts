import type { PaddingOptions } from 'maplibre-gl';
import type { GlobeView } from './globe/globe-map';
import type { Origin } from './types';

/** How close the camera comes for each kind of place. */
const ZOOM: Record<Origin['kind'], number> = {
    address: 15,
    street: 14.5,
    postcode: 13,
    city: 12.5,
    region: 9,
    place: 13,
    mosque: 14.5,
    me: 14,
};

export function zoomFor(kind: Origin['kind']): number {
    return ZOOM[kind];
}

/** Zoom that shows a search radius of `km` around the centre. */
export function zoomForRadius(km: number): number {
    return Math.max(9, 13.4 - Math.log2(Math.max(km, 1) / 5));
}

/**
 * Keeps the chosen point in the part of the map that panels do not cover:
 * the list on the start side and the mosque panel on the end side (desktop),
 * the search bar on top and the sheet at the bottom (phones).
 */
export function cameraPadding(
    dir: 'ltr' | 'rtl',
    withPanel: boolean,
): PaddingOptions {
    const width = window.innerWidth;
    const height = window.innerHeight;

    if (width < 768) {
        return {
            top: 140,
            bottom: Math.round(height * 0.45),
            left: 16,
            right: 16,
        };
    }

    const start = Math.min(440, width * 0.4);
    const end = withPanel ? Math.min(420, width * 0.35) : 40;

    return {
        top: 88,
        bottom: 40,
        left: dir === 'rtl' ? end : start,
        right: dir === 'rtl' ? start : end,
    };
}

const wrap = (lng: number) => ((((lng + 180) % 360) + 360) % 360) - 180;

/** The visible box, wrapped to ±180° and narrowed to 2° × 2° around the centre (the server's limit). */
export function dotsBox(view: GlobeView): {
    w: number;
    s: number;
    e: number;
    n: number;
} {
    const half = 0.99;
    const { center, bounds } = view;
    const lngSpan = bounds.e - bounds.w;
    const w = lngSpan > half * 2 ? center.lng - half : bounds.w;
    const e = lngSpan > half * 2 ? center.lng + half : bounds.e;
    const s = Math.max(
        -90,
        bounds.n - bounds.s > half * 2 ? center.lat - half : bounds.s,
    );
    const n = Math.min(
        90,
        bounds.n - bounds.s > half * 2 ? center.lat + half : bounds.n,
    );
    const round = (value: number) => Math.round(value * 10000) / 10000;

    return { w: round(wrap(w)), s: round(s), e: round(wrap(e)), n: round(n) };
}
