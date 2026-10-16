import { usePage } from '@inertiajs/react';
import { FileText, Upload, X } from 'lucide-react';
import { useRef, useState } from 'react';
import InputError from '@/components/input-error';
import { Button } from '@/components/ui/button';
import { intlLocale, useT } from '@/lib/i18n';
import { cn } from '@/lib/utils';

type Props = {
    name: string;
    maxMb: number;
    error?: string;
};

const ACCEPT = '.pdf,.jpg,.jpeg,.png,application/pdf,image/jpeg,image/png';
const EXTENSION = /\.(pdf|jpe?g|png)$/i;

/** Optional supporting document (PDF, JPG or PNG), checked for size before upload. */
export function DocumentField({ name, maxMb, error }: Props) {
    const t = useT();
    const { locale } = usePage().props;
    // "1.2 MB" · "1,2 Mo" · "640 كيلوبايت": the unit follows the interface language.
    const formatSize = (bytes: number) => {
        const large = bytes >= 1024 * 1024;

        return new Intl.NumberFormat(intlLocale(locale), {
            style: 'unit',
            unit: large ? 'megabyte' : 'kilobyte',
            maximumFractionDigits: large ? 1 : 0,
        }).format(bytes / (large ? 1024 * 1024 : 1024));
    };
    const input = useRef<HTMLInputElement>(null);
    const [file, setFile] = useState<{ name: string; size: number } | null>(
        null,
    );
    const [localError, setLocalError] = useState<string | null>(null);

    const clear = () => {
        if (input.current) {
            input.current.value = '';
        }

        setFile(null);
    };

    const onChange = (event: React.ChangeEvent<HTMLInputElement>) => {
        const picked = event.target.files?.[0];
        setLocalError(null);

        if (!picked) {
            setFile(null);

            return;
        }

        // The server checks the real content; this only answers faster.
        if (!EXTENSION.test(picked.name)) {
            clear();
            setLocalError(t('claims.v_document_type'));

            return;
        }

        if (picked.size > maxMb * 1024 * 1024) {
            clear();
            setLocalError(t('claims.v_document_size'));

            return;
        }

        setFile({ name: picked.name, size: picked.size });
    };

    return (
        <div className="grid gap-2">
            <span className="text-sm font-medium" id={`${name}-label`}>
                {t('claims.field_document')}
            </span>
            <input
                ref={input}
                id={name}
                name={name}
                type="file"
                accept={ACCEPT}
                className="peer sr-only"
                aria-labelledby={`${name}-label`}
                aria-describedby={`${name}-hint`}
                onChange={onChange}
            />
            {file ? (
                <div className="flex items-center gap-3 rounded-lg border bg-muted/40 px-3 py-2.5">
                    <FileText
                        className="size-5 shrink-0 text-primary"
                        aria-hidden
                    />
                    <div className="min-w-0 flex-1">
                        <p className="truncate text-sm font-medium" dir="auto">
                            {file.name}
                        </p>
                        <p className="text-xs text-muted-foreground">
                            {formatSize(file.size)}
                        </p>
                    </div>
                    <Button
                        type="button"
                        variant="ghost"
                        size="icon"
                        onClick={() => {
                            clear();
                            // Keyboard users land back on the file picker.
                            input.current?.focus();
                        }}
                        aria-label={t('claims.document_remove')}
                    >
                        <X className="size-4" />
                    </Button>
                </div>
            ) : (
                <label
                    htmlFor={name}
                    className={cn(
                        'flex cursor-pointer flex-col items-center gap-2 rounded-lg border border-dashed px-4 py-6 text-center transition-colors hover:border-primary/50 hover:bg-primary/5',
                        'peer-focus-visible:ring-[3px] peer-focus-visible:ring-ring/50',
                        (error || localError) && 'border-destructive',
                    )}
                >
                    <Upload className="size-5 text-primary" aria-hidden />
                    <span className="text-sm font-medium">
                        {t('claims.document_choose')}
                    </span>
                    <span className="text-xs text-muted-foreground">
                        {t('claims.document_types', { size: maxMb })}
                    </span>
                </label>
            )}
            <p id={`${name}-hint`} className="text-xs text-muted-foreground">
                {t('claims.document_hint')}
            </p>
            <InputError message={localError ?? error} />
        </div>
    );
}
