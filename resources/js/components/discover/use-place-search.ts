import { useCallback, useEffect, useRef, useState } from 'react';
import type { MosqueSummary } from '@/types/mosque';
import { getJson, isAbort, RequestError, withQuery } from './api';
import { searchesAsYouType } from './countries';
import type { Place } from './types';

type PlacesAnswer = { key: string; places: Place[]; error: string | null };
type MosquesAnswer = { term: string; mosques: MosqueSummary[] };

export const MIN_PLACE_QUERY = 3;
export const MIN_MOSQUE_QUERY = 2;

/**
 * Suggestions for the search box: places (as you type in France, on Enter
 * elsewhere, as Nominatim requires) and mosques whose name or city matches.
 * Answers are keyed by the text they answer, so stale ones never show.
 */
export function usePlaceSearch(
    query: string,
    country: string,
    fallbackError: string,
) {
    const term = query.trim();
    const key = `${country}|${term.toLowerCase()}`;
    const live = searchesAsYouType(country);
    const [placesAnswer, setPlacesAnswer] = useState<PlacesAnswer | null>(null);
    const [pendingKey, setPendingKey] = useState<string | null>(null);
    const [mosquesAnswer, setMosquesAnswer] = useState<MosquesAnswer | null>(
        null,
    );
    const placesAbort = useRef<AbortController | null>(null);
    const inflight = useRef<{ key: string; promise: Promise<Place[]> } | null>(
        null,
    );

    const lookUpPlaces = useCallback(
        (text: string): Promise<Place[]> => {
            const lookupKey = `${country}|${text.toLowerCase()}`;

            if (text.length < MIN_PLACE_QUERY) {
                return Promise.resolve([]);
            }

            // Enter pressed while this very text is being looked up (as you
            // type): share that request instead of cancelling it, so the
            // answer still reaches the Enter key.
            if (inflight.current?.key === lookupKey) {
                return inflight.current.promise;
            }

            placesAbort.current?.abort();
            const controller = new AbortController();
            placesAbort.current = controller;
            setPendingKey(lookupKey);

            const promise = (async () => {
                try {
                    const answer = await getJson<{ results: Place[] }>(
                        withQuery('/geocode.json', { q: text, country }),
                        controller.signal,
                    );
                    setPlacesAnswer({
                        key: lookupKey,
                        places: answer.results,
                        error: null,
                    });

                    return answer.results;
                } catch (error) {
                    if (!isAbort(error)) {
                        const message =
                            error instanceof RequestError && error.message
                                ? error.message
                                : fallbackError;
                        setPlacesAnswer({
                            key: lookupKey,
                            places: [],
                            error: message,
                        });
                    }

                    return [];
                } finally {
                    if (placesAbort.current === controller) {
                        setPendingKey(null);
                        inflight.current = null;
                    }
                }
            })();
            inflight.current = { key: lookupKey, promise };

            return promise;
        },
        [country, fallbackError],
    );

    // Search-as-you-type, only where the provider allows it.
    useEffect(() => {
        if (!live || term.length < MIN_PLACE_QUERY) {
            return;
        }

        const timer = window.setTimeout(() => void lookUpPlaces(term), 300);

        return () => window.clearTimeout(timer);
    }, [live, term, lookUpPlaces]);

    useEffect(() => {
        if (term.length < MIN_MOSQUE_QUERY) {
            return;
        }

        const controller = new AbortController();
        const timer = window.setTimeout(() => {
            getJson<{ mosques: MosqueSummary[] }>(
                withQuery('/mosques/search.json', { q: term }),
                controller.signal,
            )
                .then((answer) =>
                    setMosquesAnswer({
                        term,
                        mosques: answer.mosques.slice(0, 5),
                    }),
                )
                .catch(() => undefined);
        }, 250);

        return () => {
            window.clearTimeout(timer);
            controller.abort();
        };
    }, [term]);

    useEffect(() => () => placesAbort.current?.abort(), []);

    const answered = placesAnswer?.key === key ? placesAnswer : null;

    return {
        live,
        places: answered?.places ?? [],
        placesError: answered?.error ?? null,
        placesAnswered: answered !== null,
        loadingPlaces: pendingKey === key,
        mosques:
            term.length >= MIN_MOSQUE_QUERY && mosquesAnswer?.term === term
                ? mosquesAnswer.mosques
                : [],
        lookUpPlaces: () => lookUpPlaces(term),
    };
}
