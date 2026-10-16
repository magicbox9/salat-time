import { useEffect, useState } from 'react';
import type { LiveTimes } from '@/types/mosque';
import { getJson, isAbort } from './api';

type Answer = { slug: string; times: LiveTimes | null; failed: boolean };

/** A mosque's published times for today and tomorrow (GET /mosques/{slug}/times.json). */
export function useMosqueTimes(slug: string | null) {
    const [answer, setAnswer] = useState<Answer | null>(null);

    useEffect(() => {
        if (!slug) {
            return;
        }

        const controller = new AbortController();
        getJson<LiveTimes>(
            `/mosques/${encodeURIComponent(slug)}/times.json`,
            controller.signal,
        )
            .then((times) => setAnswer({ slug, times, failed: false }))
            .catch((error) => {
                if (!isAbort(error)) {
                    setAnswer({ slug, times: null, failed: true });
                }
            });

        return () => controller.abort();
    }, [slug]);

    const current = slug && answer?.slug === slug ? answer : null;

    return {
        times: current?.times ?? null,
        loading: slug !== null && current === null,
        failed: current?.failed ?? false,
    };
}
