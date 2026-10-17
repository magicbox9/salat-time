import { useId } from 'react';
import { cn } from '@/lib/utils';

/** Gold eight-point stars and their interlace, tiled very faintly over deep green. */
export function StarPattern({ className }: { className?: string }) {
    const id = useId().replace(/:/g, '');

    return (
        <svg
            className={cn(
                'pointer-events-none absolute inset-0 size-full',
                className,
            )}
            aria-hidden
        >
            <defs>
                <pattern
                    id={`stars-${id}`}
                    width="80"
                    height="80"
                    patternUnits="userSpaceOnUse"
                >
                    <g
                        fill="none"
                        stroke="var(--d-accent)"
                        strokeWidth="0.8"
                        strokeOpacity="0.16"
                    >
                        <rect x="22" y="22" width="36" height="36" />
                        <rect
                            x="22"
                            y="22"
                            width="36"
                            height="36"
                            transform="rotate(45 40 40)"
                        />
                        <circle cx="40" cy="40" r="8" />
                        <path d="M0 40h14M66 40h14M40 0v14M40 66v14" />
                        <path d="M0 0l14 14M80 0 66 14M0 80l14-14M80 80 66 66" />
                    </g>
                </pattern>
                <radialGradient id={`fade-${id}`} cx="50%" cy="45%" r="75%">
                    <stop offset="0" stopColor="white" stopOpacity="1" />
                    <stop offset="1" stopColor="white" stopOpacity="0.25" />
                </radialGradient>
                <mask id={`mask-${id}`}>
                    <rect
                        width="100%"
                        height="100%"
                        fill={`url(#fade-${id})`}
                    />
                </mask>
            </defs>
            <rect
                width="100%"
                height="100%"
                fill={`url(#stars-${id})`}
                mask={`url(#mask-${id})`}
            />
        </svg>
    );
}

/** One eight-point rosette (corners of the frame, row markers). */
export function Rosette({ className }: { className?: string }) {
    return (
        <svg
            viewBox="0 0 40 40"
            className={cn('shrink-0', className)}
            aria-hidden
        >
            <g fill="none" stroke="var(--d-accent)" strokeWidth="1.6">
                <rect x="9" y="9" width="22" height="22" />
                <rect
                    x="9"
                    y="9"
                    width="22"
                    height="22"
                    transform="rotate(45 20 20)"
                />
            </g>
            <circle cx="20" cy="20" r="3.4" fill="var(--d-accent)" />
        </svg>
    );
}

/** A double gold frame with a rosette in each corner. */
export function GoldFrame() {
    const corner = 'absolute size-[5.4cqmin] bg-(--d-bg) p-[0.6cqmin]';

    return (
        <div
            className="pointer-events-none absolute inset-[1.6cqmin]"
            aria-hidden
        >
            <div className="absolute inset-0 rounded-[1.2cqmin] border-[0.28cqmin] border-[color-mix(in_oklab,var(--d-accent)_70%,transparent)]" />
            <div className="absolute inset-[0.9cqmin] rounded-[0.8cqmin] border-[0.12cqmin] border-[color-mix(in_oklab,var(--d-accent)_35%,transparent)]" />
            <Rosette
                className={cn(
                    corner,
                    '-start-[2.2cqmin] -top-[2.2cqmin] rounded-full',
                )}
            />
            <Rosette
                className={cn(
                    corner,
                    '-end-[2.2cqmin] -top-[2.2cqmin] rounded-full',
                )}
            />
            <Rosette
                className={cn(
                    corner,
                    '-start-[2.2cqmin] -bottom-[2.2cqmin] rounded-full',
                )}
            />
            <Rosette
                className={cn(
                    corner,
                    '-end-[2.2cqmin] -bottom-[2.2cqmin] rounded-full',
                )}
            />
        </div>
    );
}
