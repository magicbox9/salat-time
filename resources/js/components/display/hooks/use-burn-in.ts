import { useEffect, useState } from 'react';

/** A slow walk of a few pixels, so nothing stays on the same pixels for hours. */
const STEPS: [number, number][] = [
    [0, 0],
    [2, 1],
    [3, -1],
    [1, -2],
    [-1, -2],
    [-3, 0],
    [-2, 2],
    [0, 3],
];

const EVERY_MS = 3 * 60_000;

export function useBurnInShift(enabled: boolean): { x: number; y: number } {
    const [step, setStep] = useState(0);

    useEffect(() => {
        if (!enabled) {
            return;
        }

        const id = window.setInterval(
            () => setStep((s) => (s + 1) % STEPS.length),
            EVERY_MS,
        );

        return () => window.clearInterval(id);
    }, [enabled]);

    const [x, y] = enabled ? STEPS[step] : [0, 0];

    return { x, y };
}
