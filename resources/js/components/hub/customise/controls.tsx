import type { ReactNode } from 'react';
import { useId } from 'react';
import { cn } from '@/lib/utils';

/** An accessible on/off switch with its label and an optional hint. */
export function SwitchRow({
    label,
    hint,
    checked,
    disabled = false,
    onChange,
}: {
    label: string;
    hint?: string;
    checked: boolean;
    disabled?: boolean;
    onChange: (value: boolean) => void;
}) {
    const id = useId();

    return (
        <div
            className={cn(
                'flex items-center justify-between gap-4 py-2',
                disabled && 'opacity-50',
            )}
        >
            <span className="min-w-0">
                <label htmlFor={id} className="block text-sm font-medium">
                    {label}
                </label>
                {hint && (
                    <span className="block text-xs text-muted-foreground">
                        {hint}
                    </span>
                )}
            </span>
            <button
                id={id}
                type="button"
                role="switch"
                aria-checked={checked}
                disabled={disabled}
                onClick={() => onChange(!checked)}
                className={cn(
                    'relative inline-flex h-6 w-11 shrink-0 items-center rounded-full transition-colors focus-visible:ring-[3px] focus-visible:ring-ring/50 focus-visible:outline-none',
                    checked ? 'bg-primary' : 'bg-input',
                )}
            >
                <span
                    aria-hidden
                    className={cn(
                        'inline-block size-5 rounded-full bg-background shadow-sm transition-transform',
                        checked
                            ? 'translate-x-5.5 rtl:-translate-x-5.5'
                            : 'translate-x-0.5 rtl:-translate-x-0.5',
                    )}
                />
            </button>
        </div>
    );
}

/** A small segmented choice (radio group). */
export function Segmented<T extends string>({
    label,
    value,
    options,
    onChange,
}: {
    label: string;
    value: T;
    options: {
        value: T;
        label: string;
        icon?: ReactNode;
        disabled?: boolean;
    }[];
    onChange: (value: T) => void;
}) {
    return (
        <div className="py-2">
            <p aria-hidden className="mb-2 text-sm font-medium">
                {label}
            </p>
            <div
                role="radiogroup"
                aria-label={label}
                className="grid auto-cols-fr grid-flow-col gap-1 rounded-xl bg-muted p-1"
            >
                {options.map((option) => (
                    <button
                        key={option.value}
                        type="button"
                        role="radio"
                        aria-checked={value === option.value}
                        disabled={option.disabled}
                        onClick={() => onChange(option.value)}
                        className={cn(
                            'flex items-center justify-center gap-1.5 rounded-lg px-2 py-1.5 text-sm transition-colors focus-visible:ring-[3px] focus-visible:ring-ring/50 focus-visible:outline-none disabled:opacity-40',
                            value === option.value
                                ? 'bg-background font-medium text-foreground shadow-sm'
                                : 'text-muted-foreground hover:text-foreground',
                        )}
                    >
                        {option.icon}
                        {option.label}
                    </button>
                ))}
            </div>
        </div>
    );
}

export function SheetSection({
    title,
    children,
}: {
    title: string;
    children: ReactNode;
}) {
    return (
        <section className="border-t px-5 py-4 first:border-t-0">
            <h3 className="mb-1 text-xs font-semibold tracking-wider text-muted-foreground uppercase">
                {title}
            </h3>
            {children}
        </section>
    );
}
