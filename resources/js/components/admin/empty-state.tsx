import type { LucideIcon } from 'lucide-react';
import { cn } from '@/lib/utils';

/** Calm placeholder for an empty list. */
export function EmptyState({
    icon: Icon,
    title,
    text,
    className,
}: {
    icon: LucideIcon;
    title: string;
    text?: string;
    className?: string;
}) {
    return (
        <div
            className={cn(
                'flex flex-col items-center rounded-xl border border-dashed px-6 py-12 text-center',
                className,
            )}
        >
            <span className="flex size-11 items-center justify-center rounded-full bg-primary/10 text-primary">
                <Icon className="size-5" aria-hidden />
            </span>
            <p className="mt-3 font-medium">{title}</p>
            {text && (
                <p className="mt-1 max-w-md text-sm text-muted-foreground">
                    {text}
                </p>
            )}
        </div>
    );
}
