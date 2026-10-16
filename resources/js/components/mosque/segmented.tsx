import { cn } from '@/lib/utils';

type Option<T extends string> = { value: T; label: string };

type Props<T extends string> = {
    value: T;
    options: Option<T>[];
    onChange: (value: T) => void;
    label: string;
    size?: 'sm' | 'md';
    className?: string;
    /** Ties the tabs to the panel they control (tab ids: `${idPrefix}-${value}`). */
    idPrefix?: string;
    panelId?: string;
};

/** A calm segmented control (tabs between views), keyboard and screen-reader friendly. */
export function Segmented<T extends string>({
    value,
    options,
    onChange,
    label,
    size = 'md',
    className,
    idPrefix,
    panelId,
}: Props<T>) {
    return (
        <div
            role="tablist"
            aria-label={label}
            className={cn('inline-flex rounded-xl bg-muted p-1', className)}
            onKeyDown={(event) => {
                if (event.key !== 'ArrowRight' && event.key !== 'ArrowLeft') {
                    return;
                }

                const rtl =
                    getComputedStyle(event.currentTarget).direction === 'rtl';
                const forward = (event.key === 'ArrowRight') !== rtl;
                const index = options.findIndex((o) => o.value === value);
                const next =
                    options[
                        (index + (forward ? 1 : -1) + options.length) %
                            options.length
                    ];
                onChange(next.value);
                event.currentTarget
                    .querySelector<HTMLButtonElement>(
                        `[data-value="${next.value}"]`,
                    )
                    ?.focus();
            }}
        >
            {options.map((option) => {
                const active = option.value === value;

                return (
                    <button
                        key={option.value}
                        type="button"
                        role="tab"
                        id={
                            idPrefix ? `${idPrefix}-${option.value}` : undefined
                        }
                        aria-controls={panelId}
                        aria-selected={active}
                        tabIndex={active ? 0 : -1}
                        data-value={option.value}
                        onClick={() => onChange(option.value)}
                        className={cn(
                            'rounded-lg font-medium transition-colors outline-none focus-visible:ring-2 focus-visible:ring-ring/60',
                            size === 'sm'
                                ? 'px-2.5 py-1 text-xs'
                                : 'px-3.5 py-1.5 text-sm',
                            active
                                ? 'bg-background text-foreground shadow-sm'
                                : 'text-muted-foreground hover:text-foreground',
                        )}
                    >
                        {option.label}
                    </button>
                );
            })}
        </div>
    );
}
