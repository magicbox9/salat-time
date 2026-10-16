import InputError from '@/components/input-error';
import { Label } from '@/components/ui/label';
import { cn } from '@/lib/utils';

type FieldProps = {
    id: string;
    label: string;
    hint?: string;
    error?: string;
    className?: string;
    children: React.ReactNode;
};

/** Label, control, hint and validation message, stacked. */
export function Field({
    id,
    label,
    hint,
    error,
    className,
    children,
}: FieldProps) {
    return (
        <div className={cn('grid gap-1.5', className)}>
            <Label htmlFor={id}>{label}</Label>
            {children}
            {hint && !error && (
                <p className="text-xs text-muted-foreground">{hint}</p>
            )}
            <InputError message={error} />
        </div>
    );
}

export function Textarea({
    className,
    ...props
}: React.ComponentProps<'textarea'>) {
    return (
        <textarea
            className={cn(
                'min-h-24 w-full rounded-md border border-input bg-transparent px-3 py-2 text-base shadow-xs outline-none placeholder:text-muted-foreground focus-visible:border-ring focus-visible:ring-[3px] focus-visible:ring-ring/50 aria-invalid:border-destructive md:text-sm',
                className,
            )}
            {...props}
        />
    );
}

/** A section of a long form, as a card. */
export function FormSection({
    title,
    description,
    children,
}: {
    title: string;
    description?: string;
    children: React.ReactNode;
}) {
    return (
        <section className="rounded-2xl border bg-card p-5 shadow-xs sm:p-6">
            <h2 className="font-semibold">{title}</h2>
            {description && (
                <p className="mt-1 text-sm text-muted-foreground">
                    {description}
                </p>
            )}
            <div className="mt-5 grid gap-5">{children}</div>
        </section>
    );
}
