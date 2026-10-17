import { useId } from 'react';
import InputError from '@/components/input-error';
import { Label } from '@/components/ui/label';
import { cn } from '@/lib/utils';

/** A card of related settings. */
export function Section({
    title,
    description,
    icon: Icon,
    children,
    id,
}: {
    title: string;
    description?: string;
    icon?: React.ElementType;
    children: React.ReactNode;
    id?: string;
}) {
    return (
        <section
            id={id}
            className="scroll-mt-24 rounded-2xl border bg-card p-5 shadow-xs sm:p-6"
        >
            <div className="flex items-start gap-3">
                {Icon && (
                    <span className="flex size-9 shrink-0 items-center justify-center rounded-xl bg-primary/10 text-primary">
                        <Icon className="size-4.5" aria-hidden />
                    </span>
                )}
                <div className="min-w-0">
                    <h2 className="font-semibold">{title}</h2>
                    {description && (
                        <p className="mt-0.5 text-sm text-muted-foreground">
                            {description}
                        </p>
                    )}
                </div>
            </div>
            <div className="mt-5 grid gap-5">{children}</div>
        </section>
    );
}

/** An on/off switch with its label and an optional hint. */
export function SwitchRow({
    label,
    hint,
    checked,
    onChange,
    error,
}: {
    label: string;
    hint?: string;
    checked: boolean;
    onChange: (value: boolean) => void;
    error?: string;
}) {
    const id = useId();

    return (
        <div className="flex items-start justify-between gap-4">
            <div className="min-w-0">
                <Label htmlFor={id} className="leading-snug">
                    {label}
                </Label>
                {hint && (
                    <p className="mt-0.5 text-xs text-muted-foreground">
                        {hint}
                    </p>
                )}
                <InputError message={error} />
            </div>
            <button
                id={id}
                type="button"
                role="switch"
                aria-checked={checked}
                onClick={() => onChange(!checked)}
                className={cn(
                    'relative mt-0.5 inline-flex h-6 w-11 shrink-0 items-center rounded-full transition-colors focus-visible:ring-[3px] focus-visible:ring-ring/50 focus-visible:outline-none motion-reduce:transition-none',
                    checked ? 'bg-primary' : 'bg-input dark:bg-muted',
                )}
            >
                <span
                    className={cn(
                        'inline-block size-5 rounded-full bg-white shadow-sm ring-1 ring-black/5 transition-transform motion-reduce:transition-none',
                        checked
                            ? 'translate-x-5.5 rtl:-translate-x-5.5'
                            : 'translate-x-0.5 rtl:-translate-x-0.5',
                    )}
                />
            </button>
        </div>
    );
}

/** A small set of exclusive choices drawn as a segmented control. */
export function Segmented<T extends string>({
    label,
    value,
    options,
    onChange,
    hint,
}: {
    label: string;
    value: T;
    options: { value: T; label: string; icon?: React.ElementType }[];
    onChange: (value: T) => void;
    hint?: string;
}) {
    const id = useId();

    return (
        <div className="grid content-start gap-1.5">
            <span id={id} className="text-sm font-medium">
                {label}
            </span>
            <div
                role="radiogroup"
                aria-labelledby={id}
                className="flex flex-wrap gap-1 rounded-xl bg-muted p-1"
            >
                {options.map((option) => {
                    const Icon = option.icon;
                    const selected = option.value === value;

                    return (
                        <button
                            key={option.value}
                            type="button"
                            role="radio"
                            aria-checked={selected}
                            onClick={() => onChange(option.value)}
                            className={cn(
                                'flex min-w-0 flex-1 items-center justify-center gap-1.5 rounded-lg px-3 py-1.5 text-sm font-medium whitespace-nowrap transition-colors focus-visible:ring-[3px] focus-visible:ring-ring/50 focus-visible:outline-none',
                                selected
                                    ? 'bg-background text-foreground shadow-sm'
                                    : 'text-muted-foreground hover:text-foreground',
                            )}
                        >
                            {Icon && (
                                <Icon className="size-4 shrink-0" aria-hidden />
                            )}
                            {option.label}
                        </button>
                    );
                })}
            </div>
            {hint && <p className="text-xs text-muted-foreground">{hint}</p>}
        </div>
    );
}

/** A number on a slider, with its value and unit beside it. */
export function RangeRow({
    label,
    value,
    min,
    max,
    step = 1,
    unit,
    onChange,
    error,
    hint,
}: {
    label: string;
    value: number;
    min: number;
    max: number;
    step?: number;
    unit?: string;
    onChange: (value: number) => void;
    error?: string;
    hint?: string;
}) {
    const id = useId();

    return (
        <div className="grid content-start gap-1.5">
            <div className="flex items-baseline justify-between gap-3">
                <Label htmlFor={id}>{label}</Label>
                <span
                    className="text-sm font-medium text-primary tabular-nums"
                    dir="ltr"
                >
                    {value > 0 && min < 0 ? `+${value}` : value}
                    {unit ? ` ${unit}` : ''}
                </span>
            </div>
            <input
                id={id}
                type="range"
                min={min}
                max={max}
                step={step}
                value={value}
                onChange={(event) => onChange(Number(event.target.value))}
                className="w-full accent-[var(--primary)]"
            />
            {hint && !error && (
                <p className="text-xs text-muted-foreground">{hint}</p>
            )}
            <InputError message={error} />
        </div>
    );
}

/** A native select, styled like the other inputs. */
export function SelectRow({
    label,
    value,
    options,
    onChange,
    hint,
    error,
}: {
    label: string;
    value: string;
    options: { value: string; label: string }[];
    onChange: (value: string) => void;
    hint?: string;
    error?: string;
}) {
    const id = useId();

    return (
        <div className="grid content-start gap-1.5">
            <Label htmlFor={id}>{label}</Label>
            <select
                id={id}
                value={value}
                onChange={(event) => onChange(event.target.value)}
                className="h-9 w-full rounded-md border border-input bg-transparent px-3 text-sm shadow-xs outline-none focus-visible:border-ring focus-visible:ring-[3px] focus-visible:ring-ring/50 dark:bg-input/30"
            >
                {options.map((option) => (
                    <option key={option.value} value={option.value}>
                        {option.label}
                    </option>
                ))}
            </select>
            {hint && !error && (
                <p className="text-xs text-muted-foreground">{hint}</p>
            )}
            <InputError message={error} />
        </div>
    );
}
