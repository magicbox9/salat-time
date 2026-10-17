import { useEffect, useLayoutEffect, useRef, useState } from 'react';
import type { Orientation } from '../types';

export type StageLayout = 'landscape' | 'portrait';

/**
 * Measures the frame the screen fills. "auto" follows its shape; a forced
 * orientation that differs from it turns the whole screen a quarter turn
 * (a TV mounted on its side while the device still sends a landscape picture).
 */
export function useStage(setting: Orientation, allowRotate: boolean) {
    const ref = useRef<HTMLDivElement>(null);
    const [size, setSize] = useState({ width: 16, height: 9 });

    // Measured before the first paint, so a portrait screen never flashes the landscape layout.
    useLayoutEffect(() => {
        const rect = ref.current?.getBoundingClientRect();

        if (rect && rect.width > 0 && rect.height > 0) {
            setSize({ width: rect.width, height: rect.height });
        }
    }, []);

    useEffect(() => {
        const element = ref.current;

        if (!element || typeof ResizeObserver === 'undefined') {
            return;
        }

        const observer = new ResizeObserver(([entry]) => {
            const { width, height } = entry.contentRect;

            if (width > 0 && height > 0) {
                setSize({ width, height });
            }
        });
        observer.observe(element);

        return () => observer.disconnect();
    }, []);

    const actual: StageLayout =
        size.width >= size.height ? 'landscape' : 'portrait';
    const layout: StageLayout = setting === 'auto' ? actual : setting;

    return { ref, layout, rotate: allowRotate && layout !== actual, size };
}
