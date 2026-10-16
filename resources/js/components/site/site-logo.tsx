import { cn } from '@/lib/utils';

/** The Salat Time mark: a crescent and two stars on green, as in the Mac app icon. */
export function SiteLogoMark({ className }: { className?: string }) {
    return (
        <svg
            viewBox="0 0 64 64"
            aria-hidden="true"
            className={cn('size-8 shrink-0', className)}
        >
            <rect width="64" height="64" rx="16" className="fill-primary" />
            <path
                d="M38.5 14.5a19 19 0 1 0 10.9 33.8A16 16 0 1 1 38.5 14.5Z"
                className="fill-primary-foreground"
            />
            <path
                d="m44 19 1.4 3.1 3.4.4-2.5 2.3.7 3.3-3-1.7-3 1.7.7-3.3-2.5-2.3 3.4-.4Z"
                className="fill-[var(--gold)]"
            />
            <path
                d="m50.5 31 .9 2 2.2.3-1.6 1.5.4 2.1-1.9-1.1-1.9 1.1.4-2.1-1.6-1.5 2.2-.3Z"
                className="fill-[var(--gold)]"
            />
        </svg>
    );
}

export function SiteLogo({ className }: { className?: string }) {
    return (
        <span className={cn('flex items-center gap-2', className)}>
            <SiteLogoMark />
            <span className="text-lg font-semibold tracking-tight">
                Salat Time
            </span>
        </span>
    );
}
