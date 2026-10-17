import { useEffect } from 'react';

/**
 * Keeps the screen awake (Screen Wake Lock API). The browser releases the
 * lock whenever the page is hidden, so it is taken again on return.
 */
export function useWakeLock(active: boolean): void {
    useEffect(() => {
        if (
            !active ||
            typeof navigator === 'undefined' ||
            !('wakeLock' in navigator)
        ) {
            return;
        }

        let lock: WakeLockSentinel | null = null;
        let stopped = false;

        const acquire = async () => {
            if (
                stopped ||
                document.visibilityState !== 'visible' ||
                (lock && !lock.released)
            ) {
                return;
            }

            try {
                const sentinel = await navigator.wakeLock.request('screen');

                if (stopped) {
                    void sentinel.release().catch(() => undefined);
                } else {
                    lock = sentinel;
                }
            } catch {
                // Refused (battery saver, unsupported context): the screen still runs.
            }
        };
        const onVisibility = () => void acquire();

        void acquire();
        document.addEventListener('visibilitychange', onVisibility);

        return () => {
            stopped = true;
            document.removeEventListener('visibilitychange', onVisibility);
            void lock?.release().catch(() => undefined);
        };
    }, [active]);
}
