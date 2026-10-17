import { useEffect, useRef, useState } from 'react';
import { parseCampaigns } from '../lib/campaigns';
import type { DisplayPayload, ScreenCampaign } from '../types';

/** Refresh every 30 minutes; just after the mosque's midnight too. */
const REFRESH_MS = 30 * 60_000;

/** How often (plus up to 15 s, spread out) the screen asks whether its data changed: a few bytes. */
const STAMP_MS = 45_000;

const cacheKey = (slug: string) => `salat-time:display-data:${slug}`;

function readCache(slug: string): {
    payload: DisplayPayload | null;
    campaigns: ScreenCampaign[];
} {
    if (typeof window === 'undefined') {
        return { payload: null, campaigns: [] };
    }

    try {
        const raw = window.localStorage.getItem(cacheKey(slug));
        const parsed = raw ? JSON.parse(raw) : null;

        return {
            payload: isPayload(parsed?.payload) ? parsed.payload : null,
            campaigns: Array.isArray(parsed?.campaigns)
                ? parseCampaigns(parsed.campaigns)
                : [],
        };
    } catch {
        return { payload: null, campaigns: [] };
    }
}

function writeCache(
    slug: string,
    payload: DisplayPayload,
    campaigns: ScreenCampaign[],
): void {
    try {
        window.localStorage.setItem(
            cacheKey(slug),
            JSON.stringify({ payload, campaigns }),
        );
    } catch {
        // A full storage only loses the offline copy.
    }
}

function isPayload(value: unknown): value is DisplayPayload {
    const data = value as DisplayPayload | null;

    return (
        !!data &&
        typeof data === 'object' &&
        typeof data.timezone === 'string' &&
        typeof data.generated_at === 'string' &&
        Array.isArray(data.days) &&
        !!data.mosque &&
        typeof data.mosque.slug === 'string' &&
        !!data.rotation &&
        !!data.settings
    );
}

async function getJson(url: string): Promise<unknown> {
    const response = await fetch(url, {
        headers: {
            Accept: 'application/json',
            'X-Requested-With': 'XMLHttpRequest',
        },
        credentials: 'same-origin',
        cache: 'no-store',
    });

    if (!response.ok) {
        throw new Error(String(response.status));
    }

    return response.json();
}

/**
 * The screen's data: the page's own copy first, then display.json every 30
 * minutes, after the mosque's midnight, and within a minute of any change
 * (a manager's edit, a message that starts or ends: its stamp differs). The
 * last good copy is kept in localStorage, so a screen that loses the network
 * keeps running on it (it holds a week of published times).
 */
export function useDisplayData(
    initial: DisplayPayload | null,
    mosqueDate: string | null,
) {
    const slug = initial?.mosque.slug ?? null;
    const [state, setState] = useState(() => {
        const cached = slug
            ? readCache(slug)
            : { payload: null, campaigns: [] };
        const newer =
            cached.payload &&
            initial &&
            cached.payload.generated_at > initial.generated_at;

        return {
            payload: newer ? cached.payload : initial,
            campaigns: cached.campaigns,
            offline: false,
        };
    });
    const latest = useRef(state);

    useEffect(() => {
        latest.current = state;
    }, [state]);

    const refresh = async (signal?: { cancelled: boolean }) => {
        if (!slug) {
            return;
        }

        try {
            const body = await getJson(`/mosques/${slug}/display.json`);

            if (!isPayload(body)) {
                throw new Error('invalid');
            }

            const campaigns = await getJson(`/mosques/${slug}/campaigns.json`)
                .then(parseCampaigns)
                .catch(() => latest.current.campaigns);

            if (!signal?.cancelled) {
                setState({ payload: body, campaigns, offline: false });
                writeCache(slug, body, campaigns);
            }
        } catch {
            if (!signal?.cancelled) {
                setState((current) => ({ ...current, offline: true }));
            }
        }
    };

    // First load: keep the page's copy offline and fetch the campaigns.
    useEffect(() => {
        const signal = { cancelled: false };

        if (slug && initial) {
            writeCache(slug, initial, latest.current.campaigns);
            void getJson(`/mosques/${slug}/campaigns.json`)
                .then(parseCampaigns)
                .then((campaigns) => {
                    if (!signal.cancelled) {
                        setState((current) => ({ ...current, campaigns }));
                    }
                })
                .catch(() => undefined);
        }

        const id = window.setInterval(() => void refresh(signal), REFRESH_MS);
        const online = () => void refresh(signal);
        window.addEventListener('online', online);

        return () => {
            signal.cancelled = true;
            window.clearInterval(id);
            window.removeEventListener('online', online);
        };
    }, [slug]);

    // Once a minute: has anything changed? Spread out so screens do not all ask at once.
    useEffect(() => {
        if (!slug) {
            return;
        }

        const signal = { cancelled: false };
        let timer = 0;
        const next = () => {
            timer = window.setTimeout(
                () => void check(),
                STAMP_MS + Math.random() * 15_000,
            );
        };
        const check = async () => {
            try {
                const body = (await getJson(
                    `/mosques/${slug}/display/stamp.json`,
                )) as { stamp?: unknown } | null;
                const stamp = body?.stamp;

                if (signal.cancelled) {
                    return;
                }

                if (
                    typeof stamp === 'string' &&
                    stamp !== latest.current.payload?.stamp
                ) {
                    await refresh(signal);
                } else if (latest.current.offline) {
                    setState((current) => ({ ...current, offline: false }));
                }
            } catch {
                if (!signal.cancelled && !latest.current.offline) {
                    setState((current) => ({ ...current, offline: true }));
                }
            }

            if (!signal.cancelled) {
                next();
            }
        };
        next();

        return () => {
            signal.cancelled = true;
            window.clearTimeout(timer);
        };
    }, [slug]);

    // A new day in the mosque's time zone: fetch again, spread over a minute
    // so that many screens do not all ask at the same second.
    const dataDay = state.payload?.today ?? null;

    useEffect(() => {
        if (!mosqueDate || !dataDay || mosqueDate <= dataDay) {
            return;
        }

        const signal = { cancelled: false };
        const timer = window.setTimeout(
            () => void refresh(signal),
            5000 + Math.random() * 55_000,
        );

        return () => {
            signal.cancelled = true;
            window.clearTimeout(timer);
        };
    }, [mosqueDate, dataDay]);

    return { ...state, refresh };
}
