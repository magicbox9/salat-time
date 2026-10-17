import { useLayoutEffect, useRef } from 'react';

/**
 * Shrinks a block's text (through the CSS variable --fit, 1 → 0.35) until it
 * fits its box, before it is painted and again whenever the box is resized.
 * Long verses and messages stay whole on any screen.
 */
export function useFitText<T extends HTMLElement>(key: string) {
    const ref = useRef<T>(null);

    useLayoutEffect(() => {
        const element = ref.current;

        if (!element) {
            return;
        }

        const fit = () => {
            let scale = 1;
            element.style.setProperty('--fit', '1');

            // A few pixels of rounding are not an overflow (a box sized by its content never shrinks).
            while (
                scale > 0.35 &&
                (element.scrollHeight > element.clientHeight + 4 ||
                    element.scrollWidth > element.clientWidth + 4)
            ) {
                scale *= 0.9;
                element.style.setProperty('--fit', scale.toFixed(3));
            }
        };

        fit();
        // A web font arriving later changes the text's size, not the box's.
        const fonts =
            typeof document !== 'undefined' ? document.fonts : undefined;
        fonts?.addEventListener('loadingdone', fit);

        if (typeof ResizeObserver === 'undefined') {
            return () => fonts?.removeEventListener('loadingdone', fit);
        }

        let last = '';
        const observer = new ResizeObserver(([entry]) => {
            const size = `${Math.round(entry.contentRect.width)}x${Math.round(entry.contentRect.height)}`;

            if (size !== last) {
                last = size;
                fit();
            }
        });
        observer.observe(element);

        return () => {
            observer.disconnect();
            fonts?.removeEventListener('loadingdone', fit);
        };
    }, [key]);

    return ref;
}
