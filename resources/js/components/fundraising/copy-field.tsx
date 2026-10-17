import { Check, Copy } from 'lucide-react';
import { useEffect, useState } from 'react';
import { Button } from '@/components/ui/button';
import { useClipboard } from '@/hooks/use-clipboard';
import { useT } from '@/lib/i18n';
import { cn } from '@/lib/utils';

/** A label, a value in a monospace box, and a copy button (bank details, references). */
export function CopyField({
    label,
    value,
    copyValue,
    emphasis = false,
}: {
    label: string;
    value: string;
    /** What goes to the clipboard when it differs from what is shown (an IBAN without spaces). */
    copyValue?: string;
    emphasis?: boolean;
}) {
    const t = useT();
    const [, copy] = useClipboard();
    const [copied, setCopied] = useState(false);

    useEffect(() => {
        if (!copied) {
            return;
        }

        const timer = window.setTimeout(() => setCopied(false), 2000);

        return () => window.clearTimeout(timer);
    }, [copied]);

    return (
        <div className="grid gap-1">
            <dt className="text-xs font-medium text-muted-foreground">
                {label}
            </dt>
            <dd
                className={cn(
                    'flex items-center gap-2 rounded-xl border bg-background py-1 ps-3 pe-1',
                    emphasis && 'border-gold/60 bg-gold/5',
                )}
            >
                <span
                    dir="ltr"
                    className={cn(
                        'min-w-0 flex-1 font-mono text-sm break-all',
                        emphasis && 'text-base font-semibold',
                    )}
                >
                    {value}
                </span>
                <Button
                    type="button"
                    variant="ghost"
                    size="sm"
                    className="shrink-0"
                    onClick={() =>
                        void copy(copyValue ?? value).then((ok) =>
                            setCopied(ok),
                        )
                    }
                    aria-label={t('fundraising.copy_value', { label })}
                >
                    {copied ? (
                        <Check className="size-4 text-primary" aria-hidden />
                    ) : (
                        <Copy className="size-4" aria-hidden />
                    )}
                    <span className="hidden sm:inline">
                        {copied
                            ? t('fundraising.copied')
                            : t('fundraising.copy')}
                    </span>
                </Button>
            </dd>
        </div>
    );
}
