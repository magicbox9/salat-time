import type { RefObject } from 'react';
import { useEffect, useRef, useState } from 'react';
import { getJson, isAbort, withQuery } from './api';
import { cameraPadding, dotsBox, zoomFor, zoomForRadius } from './camera';
import { metersBetween } from './format';
import type { GlobeApi, GlobeView } from './globe/globe-map';
import { DOTS_MIN_ZOOM } from './globe/map-style';
import type {
    BoundsResponse,
    MosqueCard,
    MosquePin,
    NearbyResponse,
    Origin,
} from './types';

type Nearby = { origin: Origin; radiusKm: number; mosques: MosqueCard[] };

/**
 * The globe's state: where the visitor searched from, the mosques found
 * around it, the dots in view and the selected mosque. Moving the camera is
 * part of each step (choose a place → fly down; choose a mosque → fly to it).
 */
export function useDiscover(
    globe: RefObject<GlobeApi | null>,
    dir: 'ltr' | 'rtl',
) {
    const [origin, setOrigin] = useState<Origin | null>(null);
    const [nearby, setNearby] = useState<Nearby | null>(null);
    const [loading, setLoading] = useState(false);
    const [failed, setFailed] = useState(false);
    const [selected, setSelected] = useState<MosquePin | null>(null);
    const [dots, setDots] = useState<MosquePin[]>([]);
    const [view, setView] = useState<GlobeView | null>(null);
    const nearbyAbort = useRef<AbortController | null>(null);
    const dotsAbort = useRef<AbortController | null>(null);
    const dotsTimer = useRef(0);

    useEffect(
        () => () => {
            nearbyAbort.current?.abort();
            dotsAbort.current?.abort();
            window.clearTimeout(dotsTimer.current);
        },
        [],
    );

    /** Search around a point; optionally open one mosque once the list is in. */
    const searchAround = async (
        next: Origin,
        options: { select?: MosquePin; zoom?: number } = {},
    ) => {
        setOrigin(next);
        setSelected(options.select ?? null);
        globe.current?.flyTo(
            next,
            options.zoom ?? zoomFor(next.kind),
            cameraPadding(dir, Boolean(options.select)),
        );

        nearbyAbort.current?.abort();
        const controller = new AbortController();
        nearbyAbort.current = controller;
        setLoading(true);
        setFailed(false);

        try {
            const data = await getJson<NearbyResponse>(
                withQuery('/mosques/near.json', {
                    lat: next.lat.toFixed(6),
                    lng: next.lng.toFixed(6),
                }),
                controller.signal,
            );
            setNearby({
                origin: next,
                radiusKm: data.radius_km,
                mosques: data.mosques,
            });

            if (options.select) {
                const full = data.mosques.find(
                    (m) => m.id === options.select?.id,
                );
                setSelected((current) =>
                    full && current?.id === full.id ? full : current,
                );
            } else if (options.zoom === undefined && data.radius_km > 5) {
                // Few mosques nearby: step back so the wider circle is in view.
                globe.current?.flyTo(
                    next,
                    Math.min(zoomFor(next.kind), zoomForRadius(data.radius_km)),
                    cameraPadding(dir, false),
                );
            }
        } catch (error) {
            if (!isAbort(error)) {
                setFailed(true);
            }
        } finally {
            if (nearbyAbort.current === controller) {
                setLoading(false);
            }
        }
    };

    /** Open a mosque: close to the current search it just opens, far away it becomes the new search. */
    const openMosque = (pin: MosquePin) => {
        const inList = nearby?.mosques.find((m) => m.id === pin.id);
        const close =
            origin &&
            metersBetween(origin, pin) <
                Math.max(5, (nearby?.radiusKm ?? 5) * 2) * 1000;

        if (inList || close) {
            setSelected(
                inList ?? {
                    ...pin,
                    distance_m: origin ? metersBetween(origin, pin) : null,
                },
            );
            globe.current?.flyTo(
                pin,
                Math.max(view?.zoom ?? 0, 14),
                cameraPadding(dir, true),
            );

            return;
        }

        void searchAround(
            { lat: pin.lat, lng: pin.lng, label: pin.name, kind: 'mosque' },
            { select: pin },
        );
    };

    const onViewChange = (next: GlobeView) => {
        // While the globe turns (far out) the view is not needed: skip the re-render.
        setView((previous) =>
            next.zoom < DOTS_MIN_ZOOM &&
            (!previous || previous.zoom < DOTS_MIN_ZOOM)
                ? previous
                : next,
        );
        window.clearTimeout(dotsTimer.current);

        if (next.zoom < DOTS_MIN_ZOOM) {
            return;
        }

        dotsTimer.current = window.setTimeout(() => {
            dotsAbort.current?.abort();
            const controller = new AbortController();
            dotsAbort.current = controller;
            getJson<BoundsResponse>(
                withQuery('/mosques/in-bounds.json', dotsBox(next)),
                controller.signal,
            )
                .then((data) => setDots(data.mosques))
                .catch(() => undefined);
        }, 350);
    };

    // "Search this area" once the visitor has moved well away from the last search.
    const canSearchHere = Boolean(
        origin &&
        view &&
        !loading &&
        view.zoom >= 10 &&
        metersBetween(view.center, origin) >
            Math.max(1500, (nearby?.radiusKm ?? 5) * 400),
    );

    return {
        origin,
        nearby,
        loading,
        failed,
        selected,
        dots,
        view,
        canSearchHere,
        searchAround,
        openMosque,
        onViewChange,
        close: () => setSelected(null),
        retry: () => origin && searchAround(origin, { zoom: view?.zoom }),
    };
}
