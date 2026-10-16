import { useId } from 'react';
import { cn } from '@/lib/utils';

/**
 * A quiet geometric pattern (eight-pointed stars, as on mosque tiles) in green
 * and gold, used where a mosque has not uploaded a cover picture.
 */
export function Arabesque({ className }: { className?: string }) {
    const id = useId().replace(/[^a-zA-Z0-9_-]/g, '');

    return (
        <svg
            aria-hidden="true"
            className={cn('h-full w-full', className)}
            preserveAspectRatio="xMidYMid slice"
            viewBox="0 0 720 240"
        >
            <defs>
                <linearGradient id={`${id}-bg`} x1="0" y1="0" x2="1" y2="1">
                    <stop offset="0" stopColor="oklch(0.36 0.08 168)" />
                    <stop offset="0.55" stopColor="oklch(0.42 0.09 170)" />
                    <stop offset="1" stopColor="oklch(0.3 0.06 190)" />
                </linearGradient>
                <radialGradient id={`${id}-glow`} cx="0.78" cy="0.15" r="0.7">
                    <stop
                        offset="0"
                        stopColor="oklch(0.85 0.12 85)"
                        stopOpacity="0.38"
                    />
                    <stop
                        offset="1"
                        stopColor="oklch(0.85 0.12 85)"
                        stopOpacity="0"
                    />
                </radialGradient>
                <pattern
                    id={`${id}-tile`}
                    width="72"
                    height="72"
                    patternUnits="userSpaceOnUse"
                >
                    <g
                        fill="none"
                        stroke="oklch(0.84 0.11 85)"
                        strokeWidth="1.1"
                    >
                        <rect x="22" y="22" width="28" height="28" />
                        <rect
                            x="22"
                            y="22"
                            width="28"
                            height="28"
                            transform="rotate(45 36 36)"
                        />
                        <circle cx="36" cy="36" r="6" />
                        <path d="M0 0 16.2 16.2M72 0 55.8 16.2M0 72l16.2-16.2M72 72 55.8 55.8" />
                        <path d="M36 0v10M36 72V62M0 36h10M72 36H62" />
                    </g>
                </pattern>
                <linearGradient id={`${id}-fade`} x1="0" y1="0" x2="0" y2="1">
                    <stop offset="0" stopColor="white" stopOpacity="0.9" />
                    <stop offset="1" stopColor="white" stopOpacity="0.25" />
                </linearGradient>
                <mask id={`${id}-mask`}>
                    <rect width="720" height="240" fill={`url(#${id}-fade)`} />
                </mask>
            </defs>
            <rect width="720" height="240" fill={`url(#${id}-bg)`} />
            <rect
                width="720"
                height="240"
                fill={`url(#${id}-tile)`}
                opacity="0.32"
                mask={`url(#${id}-mask)`}
            />
            <rect width="720" height="240" fill={`url(#${id}-glow)`} />
        </svg>
    );
}
