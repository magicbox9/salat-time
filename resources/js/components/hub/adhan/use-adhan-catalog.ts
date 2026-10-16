import { useEffect, useState } from 'react';
import { getJson, isAbort } from '@/components/discover/api';
import type { AdhanTrack } from '../types';

/** Same pattern as App\Http\Controllers\Hub\Support\HubPreferences (adhan_id). */
const SAVABLE_ID = /^[A-Za-z0-9_.:-]{1,64}$/;

/** Only playable http(s) or same-origin URLs are kept. */
function playable(url: unknown): url is string {
    if (typeof url !== 'string' || url === '') {
        return false;
    }

    try {
        const parsed = new URL(url, window.location.origin);

        return parsed.protocol === 'https:' || parsed.protocol === 'http:';
    } catch {
        return false;
    }
}

/**
 * The adhan recordings offered by GET /adhan/catalog.json. A missing
 * endpoint, an error or an empty list all mean "no recording": the hub then
 * offers the visual adhan only.
 */
export function useAdhanCatalog(): { tracks: AdhanTrack[]; loaded: boolean } {
    const [state, setState] = useState<{
        tracks: AdhanTrack[];
        loaded: boolean;
    }>({
        tracks: [],
        loaded: false,
    });

    useEffect(() => {
        const controller = new AbortController();

        getJson<{ adhans?: unknown }>('/adhan/catalog.json', controller.signal)
            .then((body) => {
                const list: unknown[] = Array.isArray(body?.adhans)
                    ? body.adhans
                    : [];
                const tracks = list.flatMap((item): AdhanTrack[] => {
                    if (!item || typeof item !== 'object') {
                        return [];
                    }

                    const { id, name, url } = item as Record<string, unknown>;
                    // A numeric id (a database key) is kept as text.
                    const key =
                        typeof id === 'number' && Number.isInteger(id)
                            ? String(id)
                            : id;

                    // Only ids the account can store (HubPreferences::rules).
                    return typeof key === 'string' &&
                        SAVABLE_ID.test(key) &&
                        typeof name === 'string' &&
                        name.trim() !== '' &&
                        playable(url)
                        ? [{ id: key, name, url }]
                        : [];
                });
                setState({ tracks, loaded: true });
            })
            .catch((error) => {
                if (!isAbort(error)) {
                    setState({ tracks: [], loaded: true });
                }
            });

        return () => controller.abort();
    }, []);

    return state;
}
