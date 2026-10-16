import { useEffect, useState } from 'react';
import type { DayTimes, LiveTimes } from '@/types/mosque';
import { api } from './api';
import { todayIn } from './calendar';

type Live = Omit<LiveTimes, 'days'>;

/**
 * Today's and tomorrow's published times, refreshed when the mosque's local
 * day changes while the page stays open (after midnight, or after a sleep).
 */
export function useLiveTimes(slug: string, initial: Live): Live {
    const [live, setLive] = useState(initial);

    useEffect(() => setLive(initial), [initial]);

    useEffect(() => {
        if (!live.today) {
            return;
        }

        const check = () => {
            if (live.today && todayIn(live.timezone) !== live.today.date) {
                api<LiveTimes>('GET', `/mosques/${slug}/times.json`)
                    .then((fresh) => setLive(fresh))
                    .catch(() => undefined);
            }
        };
        const id = window.setInterval(check, 60_000);
        document.addEventListener('visibilitychange', check);

        return () => {
            window.clearInterval(id);
            document.removeEventListener('visibilitychange', check);
        };
    }, [slug, live]);

    return live;
}

type RangeState = {
    key: string;
    days: DayTimes[];
    loading: boolean;
    failed: boolean;
};

/** A run of published days (week or month view), cached per range. */
export function useTimesRange(
    slug: string,
    from: string,
    days: number,
): RangeState {
    const key = `${from}:${days}`;
    const [state, setState] = useState<RangeState>({
        key: '',
        days: [],
        loading: true,
        failed: false,
    });

    useEffect(() => {
        let cancelled = false;
        const cached = rangeCache.get(`${slug}:${key}`);

        if (cached) {
            setState({ key, days: cached, loading: false, failed: false });

            return;
        }

        setState((s) => ({ ...s, key, loading: true, failed: false }));
        api<LiveTimes>(
            'GET',
            `/mosques/${slug}/times.json?from=${from}&days=${days}`,
        )
            .then((data) => {
                rangeCache.set(`${slug}:${key}`, data.days);

                if (!cancelled) {
                    setState({
                        key,
                        days: data.days,
                        loading: false,
                        failed: false,
                    });
                }
            })
            .catch(() => {
                if (!cancelled) {
                    setState({ key, days: [], loading: false, failed: true });
                }
            });

        return () => {
            cancelled = true;
        };
    }, [slug, key, from, days]);

    // Until the effect has started the new request, never show the previous range.
    return state.key === key
        ? state
        : { key, days: [], loading: true, failed: false };
}

const rangeCache = new Map<string, DayTimes[]>();
