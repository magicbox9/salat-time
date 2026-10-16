import { Link } from '@inertiajs/react';
import type { LucideIcon } from 'lucide-react';
import { cn } from '@/lib/utils';
import { useFormatNumber } from './use-format-number';

type Props = {
    label: string;
    value: number;
    icon: LucideIcon;
    /** Secondary line, e.g. a share of the total. */
    hint?: string;
    href?: string;
    highlight?: boolean;
};

/** One platform figure on the admin overview. */
export function StatCard({
    label,
    value,
    icon: Icon,
    hint,
    href,
    highlight,
}: Props) {
    const formatNumber = useFormatNumber();
    const body = (
        <div
            className={cn(
                'flex h-full flex-col gap-3 rounded-xl border bg-card p-4 shadow-sm transition-colors sm:p-5',
                href && 'hover:border-primary/40',
                highlight && 'border-gold/50 bg-gold/10',
            )}
        >
            <div className="flex items-center justify-between gap-2">
                <span className="text-sm text-muted-foreground">{label}</span>
                <Icon
                    className={cn(
                        'size-4',
                        highlight
                            ? 'text-amber-700 dark:text-gold'
                            : 'text-primary',
                    )}
                    aria-hidden
                />
            </div>
            <p className="text-2xl font-semibold tracking-tight tabular-nums sm:text-3xl">
                <span dir="ltr">{formatNumber(value)}</span>
            </p>
            {hint && (
                <span className="text-xs text-muted-foreground">{hint}</span>
            )}
        </div>
    );

    return href ? (
        <Link
            href={href}
            className="block h-full rounded-xl focus-visible:ring-[3px] focus-visible:ring-ring/50 focus-visible:outline-none"
        >
            {body}
        </Link>
    ) : (
        body
    );
}
