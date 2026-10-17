import { useEffect, useState } from 'react';

/** True for a few seconds after the mouse moves, the screen is touched or a key is pressed. */
export function useActivity(hideAfterMs = 3500): boolean {
    const [active, setActive] = useState(false);

    useEffect(() => {
        let timer = 0;
        const wake = () => {
            setActive(true);
            window.clearTimeout(timer);
            timer = window.setTimeout(() => setActive(false), hideAfterMs);
        };
        const events = [
            'pointermove',
            'pointerdown',
            'keydown',
            'touchstart',
        ] as const;

        events.forEach((name) =>
            window.addEventListener(name, wake, { passive: true }),
        );

        return () => {
            window.clearTimeout(timer);
            events.forEach((name) => window.removeEventListener(name, wake));
        };
    }, [hideAfterMs]);

    return active;
}
