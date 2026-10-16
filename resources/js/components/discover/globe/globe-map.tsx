import type {
    FlyToOptions,
    IControl,
    Map as MapLibreMap,
    PaddingOptions,
} from 'maplibre-gl';
import type { Ref } from 'react';
import { useEffect, useImperativeHandle, useRef, useState } from 'react';
import { cn } from '@/lib/utils';
import type { MosquePin } from '../types';
import type { OriginPoint } from './layers';
import { CLICKABLE, installLayers } from './layers';
import type { MapTheme } from './map-style';
import {
    GLOBE_VIEW,
    prefersReducedMotion,
    SKY,
    STYLE_URLS,
    tintDarkStyle,
} from './map-style';
import { installImages } from './marker-images';
import type { Spin } from './spin';
import { startSpin } from './spin';
import { useGlobeData } from './use-globe-data';
import { useMapHover } from './use-map-hover';

export type GlobeView = {
    center: { lat: number; lng: number };
    zoom: number;
    bounds: { w: number; s: number; e: number; n: number };
};

export type GlobeApi = {
    flyTo: (
        point: { lat: number; lng: number },
        zoom: number,
        padding?: PaddingOptions,
    ) => void;
    stopSpin: () => void;
};

type Props = {
    ref?: Ref<GlobeApi>;
    theme: MapTheme;
    dir: 'ltr' | 'rtl';
    label: string;
    nearby: MosquePin[];
    dots: MosquePin[];
    favorites: MosquePin[];
    origin: OriginPoint;
    selected: MosquePin | null;
    highlightId: number | null;
    nameOf: (id: number) => string | null;
    onSelect: (id: number) => void;
    onViewChange: (view: GlobeView) => void;
    /** The visitor dragged, zoomed or scrolled the map themselves. */
    onInteract?: () => void;
    onFail: () => void;
    className?: string;
};

/**
 * The 3D globe (MapLibre GL, globe projection, OpenFreeMap tiles): it turns
 * slowly until a place is chosen, then flies down to the street. Mosques are
 * drawn as GeoJSON layers (nearby points, dots in view, the visitor's stars).
 */
export function GlobeMap({
    ref,
    theme,
    dir,
    label,
    nearby,
    dots,
    favorites,
    origin,
    selected,
    highlightId,
    nameOf,
    onSelect,
    onViewChange,
    onInteract,
    onFail,
    className,
}: Props) {
    const container = useRef<HTMLDivElement>(null);
    const tooltip = useRef<HTMLDivElement>(null);
    const mapRef = useRef<MapLibreMap | null>(null);
    const spinRef = useRef<Spin | null>(null);
    const themeRef = useRef(theme);
    const appliedTheme = useRef(theme);
    const callbacks = useRef({
        onSelect,
        onViewChange,
        onInteract,
        onFail,
        nameOf,
    });
    const zoomControl = useRef<IControl | null>(null);
    // A flight asked for before MapLibre has loaded waits here; once any flight
    // is asked for, the first style load must not reset the camera's padding.
    const pendingFlight = useRef<FlyToOptions | null>(null);
    const flown = useRef(false);
    const [styleVersion, setStyleVersion] = useState(0);

    useEffect(() => {
        callbacks.current = {
            onSelect,
            onViewChange,
            onInteract,
            onFail,
            nameOf,
        };
    });

    useEffect(() => {
        let map: MapLibreMap | null = null;
        let cancelled = false;

        // Loaded on demand: keeps MapLibre out of the first paint and out of SSR.
        Promise.all([
            import('maplibre-gl'),
            import('maplibre-gl/dist/maplibre-gl.css'),
        ])
            .then(([maplibre]) => {
                if (cancelled || !container.current) {
                    return;
                }

                const small = window.innerWidth < 768;
                map = new maplibre.Map({
                    container: container.current,
                    style: STYLE_URLS[themeRef.current],
                    center: GLOBE_VIEW.center,
                    zoom: small ? GLOBE_VIEW.mobileZoom : GLOBE_VIEW.zoom,
                    minZoom: 0.6,
                    attributionControl: { compact: true },
                    pitchWithRotate: false,
                    dragRotate: false,
                });
                const instance = map;
                let lifted = false;
                mapRef.current = instance;
                appliedTheme.current = themeRef.current;

                instance.on('style.load', () => {
                    instance.setProjection({ type: 'globe' });
                    instance.setSky(SKY);

                    if (themeRef.current === 'dark') {
                        tintDarkStyle(instance);
                    }

                    // The search card sits under the globe at first: lift the globe above it
                    // (once the globe projection is in place, which would reset it). Not
                    // after a flight has started: setPadding jumps, which would stop it.
                    if (!lifted && !flown.current) {
                        const lift = small
                            ? GLOBE_VIEW.mobileLiftRatio
                            : GLOBE_VIEW.liftRatio;
                        instance.setPadding({
                            top: 64,
                            bottom: Math.round(window.innerHeight * lift),
                            left: 0,
                            right: 0,
                        });
                    }

                    lifted = true;
                    installImages(instance, themeRef.current);
                    installLayers(instance, themeRef.current);
                    setStyleVersion((v) => v + 1);
                });
                zoomControl.current = new maplibre.NavigationControl({
                    showCompass: false,
                });
                instance.on('click', (event) => {
                    const layers = CLICKABLE.filter((id) =>
                        instance.getLayer(id),
                    );
                    const feature = instance.queryRenderedFeatures(
                        event.point,
                        { layers },
                    )[0];
                    const id = Number(feature?.properties?.id);

                    if (id) {
                        callbacks.current.onSelect(id);
                    }
                });
                instance.on('moveend', () => {
                    const center = instance.getCenter();
                    const bounds = instance.getBounds();
                    callbacks.current.onViewChange({
                        center: { lat: center.lat, lng: center.wrap().lng },
                        zoom: instance.getZoom(),
                        bounds: {
                            w: bounds.getWest(),
                            s: bounds.getSouth(),
                            e: bounds.getEast(),
                            n: bounds.getNorth(),
                        },
                    });
                });
                instance.on('movestart', (event) => {
                    if (event.originalEvent) {
                        callbacks.current.onInteract?.();
                    }
                });
                instance.on('error', () => undefined);
                spinRef.current = startSpin(instance, prefersReducedMotion());

                if (pendingFlight.current) {
                    spinRef.current.stop();
                    instance.flyTo(pendingFlight.current);
                    pendingFlight.current = null;
                }
            })
            .catch(() => callbacks.current.onFail());

        return () => {
            cancelled = true;
            spinRef.current?.stop();
            spinRef.current = null;
            map?.remove();
            mapRef.current = null;
        };
    }, []);

    // Zoom buttons on the end side (the results list covers the start side).
    const ready = styleVersion > 0;
    useEffect(() => {
        const map = mapRef.current;
        const control = zoomControl.current;

        if (!map || !control || !ready) {
            return;
        }

        map.addControl(control, dir === 'rtl' ? 'bottom-left' : 'bottom-right');

        return () => {
            if (mapRef.current === map) {
                map.removeControl(control);
            }
        };
    }, [dir, ready]);

    useMapHover(mapRef, tooltip, styleVersion, callbacks);

    // Light / dark tiles follow the site theme; our layers come back on style.load.
    useEffect(() => {
        themeRef.current = theme;
        const map = mapRef.current;

        if (map && appliedTheme.current !== theme) {
            appliedTheme.current = theme;
            map.setStyle(STYLE_URLS[theme], { diff: false });
        }
    }, [theme]);

    useGlobeData(mapRef, styleVersion, {
        nearby,
        dots,
        favorites,
        origin,
        selected,
        highlightId,
    });

    useImperativeHandle(
        ref,
        () => ({
            flyTo: (point, zoom, padding) => {
                const flight: FlyToOptions = {
                    center: [point.lng, point.lat],
                    zoom,
                    padding,
                    speed: 1.2,
                    curve: 1.5,
                };
                flown.current = true;
                spinRef.current?.stop();

                if (mapRef.current) {
                    mapRef.current.flyTo(flight);
                } else {
                    pendingFlight.current = flight;
                }
            },
            stopSpin: () => spinRef.current?.stop(),
        }),
        [],
    );

    return (
        <div className={cn('absolute inset-0', className)}>
            {/* MapLibre's own (unlayered) CSS makes its container position: relative, so it fills the wrapper by size. */}
            <div
                ref={container}
                role="region"
                aria-label={label}
                className="h-full w-full max-md:[&_.maplibregl-ctrl-group]:hidden"
            />
            <div
                ref={tooltip}
                aria-hidden
                // Physical left/top: positioned from the map's pixel coordinates.
                className="pointer-events-none absolute top-0 left-0 z-10 hidden max-w-60 truncate rounded-md bg-popover/95 px-2 py-1 text-xs font-medium text-popover-foreground shadow-md"
            />
        </div>
    );
}
