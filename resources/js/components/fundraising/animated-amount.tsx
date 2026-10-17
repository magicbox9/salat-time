import { useEffect, useRef, useState } from 'react';
import { prefersReducedMotion } from './format';

type Props = {
    value: number;
    format: (value: number) => string;
    className?: string;
    /** Milliseconds; the counter jumps at once when motion is reduced. */
    duration?: number;
};

/**
 * A number that counts smoothly from its previous value to the new one when
 * live figures change (ease-out, about a second).
 */
export function AnimatedAmount({
    value,
    format,
    className,
    duration = 1100,
}: Props) {
    const [shown, setShown] = useState(value);
    const from = useRef(value);
    const frame = useRef<number | null>(null);

    useEffect(() => {
        const start = from.current;

        if (start === value || prefersReducedMotion()) {
            from.current = value;
            setShown(value);

            return;
        }

        const began = performance.now();
        const step = (now: number) => {
            const t = Math.min(1, (now - began) / duration);
            const eased = 1 - Math.pow(1 - t, 3);
            const current = Math.round(start + (value - start) * eased);
            setShown(current);
            from.current = current;

            if (t < 1) {
                frame.current = requestAnimationFrame(step);
            }
        };
        frame.current = requestAnimationFrame(step);

        return () => {
            if (frame.current !== null) {
                cancelAnimationFrame(frame.current);
            }
        };
    }, [value, duration]);

    return (
        <span className={className} dir="ltr">
            {format(shown)}
        </span>
    );
}
