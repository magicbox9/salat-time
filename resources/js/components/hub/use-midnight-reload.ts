import { router } from '@inertiajs/react';
import { useEffect, useState } from 'react';

/** Wait a little after the mosque's midnight so the server is on the new day too. */
const FIRST_DELAY_MS = 5000;

/** Then try again (offline, or a device clock ahead of the server's). */
const RETRY_DELAY_MS = 60_000;

const MAX_ATTEMPTS = 30;

/**
 * Once the mosque's date (`date`) has moved past the published day the page
 * fetched (`fetchedDate`), reload only the live times and the tracker —
 * and keep trying, gently, until the server answers with the new day.
 */
export function useMidnightReload(date: string, fetchedDate: string | null) {
    const [tries, setTries] = useState({ date: '', count: 0 });
    const count = tries.date === date ? tries.count : 0;

    useEffect(() => {
        // Only forward: a device clock behind the server's needs no reload.
        if (!date || !fetchedDate || date <= fetchedDate) {
            return;
        }

        if (count >= MAX_ATTEMPTS) {
            return;
        }

        const timer = window.setTimeout(
            () =>
                router.reload({
                    only: ['live', 'tracker'],
                    onFinish: () =>
                        setTries((previous) => ({
                            date,
                            count:
                                (previous.date === date ? previous.count : 0) +
                                1,
                        })),
                }),
            count === 0 ? FIRST_DELAY_MS : RETRY_DELAY_MS,
        );

        return () => window.clearTimeout(timer);
    }, [date, fetchedDate, count]);
}
