import type { SkySpecification } from 'maplibre-gl';

export type MapTheme = 'light' | 'dark';

/** OpenFreeMap styles (free, no key). Liberty shows shaded relief on the globe. */
export const STYLE_URLS: Record<MapTheme, string> = {
    light: 'https://tiles.openfreemap.org/styles/liberty',
    dark: 'https://tiles.openfreemap.org/styles/dark',
};

/** The globe as it first appears: Europe, Africa and the Middle East facing the visitor. */
export const GLOBE_VIEW = {
    center: [14, 26] as [number, number],
    zoom: 1.55,
    mobileZoom: 0.6,
    /** Share of the screen height kept under the globe for the search card. */
    liftRatio: 0.3,
    mobileLiftRatio: 0.52,
};

/** Zoom level from which every mosque in view is drawn as a small dot. */
export const DOTS_MIN_ZOOM = 9;

/** Above this zoom the globe no longer spins on its own. */
export const SPIN_MAX_ZOOM = 4;

/** A soft atmosphere around the globe that fades away as the camera comes down. */
export const SKY: SkySpecification = {
    'sky-color': '#0b1c27',
    'horizon-color': '#24525e',
    'fog-color': '#0f2732',
    'sky-horizon-blend': 0.6,
    'horizon-fog-blend': 0.7,
    'fog-ground-blend': 0.6,
    'atmosphere-blend': ['interpolate', ['linear'], ['zoom'], 0, 1, 5, 1, 8, 0],
};

/** Marker colours (MapLibre needs plain CSS colours, close to the app's oklch tokens). */
export const PALETTE: Record<
    MapTheme,
    { times: string; noTimes: string; gold: string; ring: string; halo: string }
> = {
    light: {
        times: '#0f6b56',
        noTimes: '#8593a1',
        gold: '#c99a1e',
        ring: '#ffffff',
        halo: '#0f6b56',
    },
    dark: {
        times: '#4fbf9a',
        noTimes: '#7b8a98',
        gold: '#e3c35f',
        ring: '#0b1d26',
        halo: '#e3c35f',
    },
};

export function prefersReducedMotion(): boolean {
    return (
        typeof window !== 'undefined' &&
        window.matchMedia('(prefers-reduced-motion: reduce)').matches
    );
}

export { tintDarkStyle } from '@/lib/map-theme';
