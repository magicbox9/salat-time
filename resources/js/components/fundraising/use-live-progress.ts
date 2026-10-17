import { useEffect, useRef, useState } from 'react';
import { api } from '@/components/mosque/api';
import type { CampaignProgress } from './types';

const INTERVAL_MS = 10_000;

/**
 * The campaign's figures, refreshed every ~10 s from progress.json while the
 * tab is visible (at once when it becomes visible again). `bump` turns true
 * for a moment when the raised amount grows, for a gentle highlight.
 *
 * New figures from the server (another campaign opened in the same page
 * component, or a reload) replace the polled ones at once.
 */
export function useLiveProgress(
    slug: string,
    initial: CampaignProgress,
    enabled: boolean,
): { progress: CampaignProgress; bump: boolean } {
    const [live, setLive] = useState({ source: initial, progress: initial });
    const [bump, setBump] = useState(false);
    const last = useRef(initial.raised);

    let progress = live.progress;

    if (live.source !== initial) {
        progress = initial;
        setLive({ source: initial, progress: initial });
    }

    useEffect(() => {
        last.current = initial.raised;
    }, [initial]);

    useEffect(() => {
        if (!enabled) {
            return;
        }

        let alive = true;
        let bumpTimer: number | undefined;

        const load = () => {
            if (document.hidden) {
                return;
            }

            api<CampaignProgress>('GET', `/campaigns/${slug}/progress.json`)
                .then((next) => {
                    if (!alive) {
                        return;
                    }

                    if (next.raised > last.current) {
                        setBump(true);
                        window.clearTimeout(bumpTimer);
                        bumpTimer = window.setTimeout(
                            () => setBump(false),
                            2400,
                        );
                    }

                    last.current = next.raised;
                    setLive((current) => ({ ...current, progress: next }));
                })
                .catch(() => undefined);
        };

        const timer = window.setInterval(load, INTERVAL_MS);
        const onVisible = () => !document.hidden && load();
        document.addEventListener('visibilitychange', onVisible);

        return () => {
            alive = false;
            window.clearInterval(timer);
            window.clearTimeout(bumpTimer);
            document.removeEventListener('visibilitychange', onVisible);
        };
    }, [slug, enabled]);

    return { progress, bump };
}
