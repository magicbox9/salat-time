import { useState } from 'react';

/** Today's counts, kept on this device only and reset each new day. */
type CategoryProgress = { counts: Record<string, number>; done: number };
type DayProgress = {
    day: string;
    categories: Record<string, CategoryProgress>;
};

const KEY = 'adhkar:progress';

function today(): string {
    const now = new Date();
    const pad = (n: number) => String(n).padStart(2, '0');

    return `${now.getFullYear()}-${pad(now.getMonth() + 1)}-${pad(now.getDate())}`;
}

function isRecord(value: unknown): value is Record<string, unknown> {
    return typeof value === 'object' && value !== null && !Array.isArray(value);
}

/** Only well-formed entries survive: a stale or edited value never breaks the page. */
function clean(categories: Record<string, unknown>): DayProgress['categories'] {
    const result: DayProgress['categories'] = {};
    for (const [key, entry] of Object.entries(categories)) {
        if (!isRecord(entry) || !isRecord(entry.counts)) {
            continue;
        }
        const counts: Record<string, number> = {};
        for (const [id, count] of Object.entries(entry.counts)) {
            if (Number.isInteger(count) && (count as number) > 0) {
                counts[id] = count as number;
            }
        }
        result[key] = {
            counts,
            done: Number.isInteger(entry.done) ? (entry.done as number) : 0,
        };
    }

    return result;
}

function load(): DayProgress {
    const empty = { day: today(), categories: {} };
    try {
        const value: unknown = JSON.parse(
            window.localStorage.getItem(KEY) ?? 'null',
        );

        return isRecord(value) &&
            value.day === empty.day &&
            isRecord(value.categories)
            ? { day: empty.day, categories: clean(value.categories) }
            : empty;
    } catch {
        return empty;
    }
}

function save(progress: DayProgress): void {
    try {
        window.localStorage.setItem(KEY, JSON.stringify(progress));
    } catch {
        // Progress is a convenience; counting still works without storage.
    }
}

/** Completed adhkar per category today, for the category grid. */
export function useAdhkarDoneToday(): Record<string, number> {
    const [done] = useState(() => {
        const result: Record<string, number> = {};
        for (const [key, value] of Object.entries(load().categories)) {
            result[key] = value.done;
        }

        return result;
    });

    return done;
}

/** Tap counts for one category's adhkar. `totals` maps dhikr id → required count. */
export function useCategoryProgress(
    category: string,
    totals: Record<string, number>,
) {
    const [counts, setCounts] = useState<Record<string, number>>(
        () => load().categories[category]?.counts ?? {},
    );

    const persist = (next: Record<string, number>) => {
        const progress = load();
        const done = Object.entries(totals).filter(
            ([id, total]) => (next[id] ?? 0) >= total,
        ).length;
        progress.categories[category] = { counts: next, done };
        save(progress);
        setCounts(next);
    };

    return {
        counts,
        /** Adds one; returns true when this tap completes the dhikr. */
        increment: (id: string): boolean => {
            const total = totals[id] ?? 1;
            const current = counts[id] ?? 0;
            if (current >= total) {
                return false;
            }
            persist({ ...counts, [id]: current + 1 });

            return current + 1 >= total;
        },
        reset: (id: string) => {
            const next = { ...counts };
            delete next[id];
            persist(next);
        },
        resetAll: () => persist({}),
    };
}
