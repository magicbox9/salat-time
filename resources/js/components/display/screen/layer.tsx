import { cn } from '@/lib/utils';

/** A full-screen moment drawn over the theme (adhan, iqama, prayer, adhkar). */
export function Layer({
    children,
    className,
    style,
}: {
    children: React.ReactNode;
    className?: string;
    style?: React.CSSProperties;
}) {
    return (
        <div
            className={cn(
                'd-fade absolute inset-0 z-20 flex flex-col items-center justify-center overflow-hidden p-[5cqmin] text-center',
                className,
            )}
            style={{ background: 'var(--d-bg)', ...style }}
            role="status"
            aria-live="polite"
        >
            {children}
        </div>
    );
}
