import type { ReactNode } from 'react';
import { cn } from '@/lib/utils';

/** A titled card section used across the admin detail pages. */
export function Panel({
    title,
    description,
    actions,
    children,
    className,
}: {
    title: string;
    description?: string;
    actions?: ReactNode;
    children: ReactNode;
    className?: string;
}) {
    return (
        <section
            className={cn('rounded-xl border bg-card shadow-sm', className)}
        >
            <div className="flex flex-wrap items-start justify-between gap-3 border-b px-5 py-4">
                <div className="min-w-0">
                    <h2 className="font-semibold">{title}</h2>
                    {description && (
                        <p className="mt-0.5 text-sm text-muted-foreground">
                            {description}
                        </p>
                    )}
                </div>
                {actions}
            </div>
            <div className="p-5">{children}</div>
        </section>
    );
}

/** Label / value pairs. */
export function InfoList({
    children,
    className,
}: {
    children: ReactNode;
    className?: string;
}) {
    return <dl className={cn('grid gap-4 text-sm', className)}>{children}</dl>;
}

export function InfoRow({
    label,
    children,
}: {
    label: string;
    children: ReactNode;
}) {
    return (
        <div className="min-w-0">
            <dt className="text-xs text-muted-foreground">{label}</dt>
            <dd className="mt-0.5 break-words">{children}</dd>
        </div>
    );
}
