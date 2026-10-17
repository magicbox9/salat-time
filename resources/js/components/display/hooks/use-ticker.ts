import { useEffect, useState } from 'react';

/**
 * The current time, refreshed right after each new second so the big clock
 * ticks in step with real seconds (useNow's interval drifts).
 */
export function useTicker(enabled = true): Date {
    const [now, setNow] = useState(() => new Date());

    useEffect(() => {
        if (!enabled) {
            return;
        }

        let timer = 0;
        const tick = () => {
            setNow(new Date());
            timer = window.setTimeout(tick, 1000 - (Date.now() % 1000) + 8);
        };
        timer = window.setTimeout(tick, 1000 - (Date.now() % 1000) + 8);

        return () => window.clearTimeout(timer);
    }, [enabled]);

    return now;
}
