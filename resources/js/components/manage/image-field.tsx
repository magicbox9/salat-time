import { ImagePlus, Trash2, Undo2 } from 'lucide-react';
import { useEffect, useId, useRef, useState } from 'react';
import InputError from '@/components/input-error';
import { Button } from '@/components/ui/button';
import { useT } from '@/lib/i18n';
import { cn } from '@/lib/utils';

export const MAX_IMAGE_BYTES = 4 * 1024 * 1024;
const ACCEPT = 'image/jpeg,image/png,image/webp';

type Props = {
    label: string;
    hint?: string;
    currentUrl: string | null;
    file: File | null;
    removed: boolean;
    onFile: (file: File | null) => void;
    onRemove: (removed: boolean) => void;
    error?: string;
    shape?: 'square' | 'wide';
};

/** Choose, preview, replace or remove a picture (JPEG, PNG or WebP, 4 MB at most). */
export function ImageField({
    label,
    hint,
    currentUrl,
    file,
    removed,
    onFile,
    onRemove,
    error,
    shape = 'wide',
}: Props) {
    const t = useT();
    const id = useId();
    const input = useRef<HTMLInputElement>(null);
    const [preview, setPreview] = useState<string | null>(null);
    const [localError, setLocalError] = useState<string | null>(null);

    useEffect(() => {
        if (!file) {
            setPreview(null);

            return;
        }

        const url = URL.createObjectURL(file);
        setPreview(url);

        return () => URL.revokeObjectURL(url);
    }, [file]);

    const shown = preview ?? (removed ? null : currentUrl);

    const choose = (picked: File | undefined) => {
        if (!picked) {
            return;
        }

        if (!ACCEPT.split(',').includes(picked.type)) {
            setLocalError(t('manage.image_type'));

            return;
        }

        if (picked.size > MAX_IMAGE_BYTES) {
            setLocalError(t('manage.image_too_big'));

            return;
        }

        setLocalError(null);
        onRemove(false);
        onFile(picked);
    };

    return (
        <div className="grid gap-2">
            <label htmlFor={id} className="text-sm font-medium">
                {label}
            </label>
            <div className="flex flex-col gap-3 sm:flex-row sm:items-center">
                <div
                    className={cn(
                        'relative flex shrink-0 items-center justify-center overflow-hidden rounded-xl border bg-muted',
                        shape === 'square'
                            ? 'size-24'
                            : 'aspect-[3/1] w-full sm:w-72',
                    )}
                >
                    {shown ? (
                        <img
                            src={shown}
                            alt=""
                            className="h-full w-full object-cover"
                        />
                    ) : (
                        <ImagePlus className="size-6 text-muted-foreground" />
                    )}
                </div>
                <div className="flex flex-wrap gap-2">
                    <input
                        ref={input}
                        id={id}
                        type="file"
                        accept={ACCEPT}
                        className="sr-only"
                        onChange={(event) => {
                            choose(event.target.files?.[0]);
                            event.target.value = '';
                        }}
                    />
                    <Button
                        type="button"
                        variant="outline"
                        size="sm"
                        onClick={() => input.current?.click()}
                    >
                        <ImagePlus className="size-4" />
                        {shown
                            ? t('manage.replace_image')
                            : t('manage.choose_image')}
                    </Button>
                    {file && (
                        <Button
                            type="button"
                            variant="ghost"
                            size="sm"
                            onClick={() => onFile(null)}
                        >
                            <Undo2 className="size-4" />
                            {t('manage.undo')}
                        </Button>
                    )}
                    {!file && currentUrl && !removed && (
                        <Button
                            type="button"
                            variant="ghost"
                            size="sm"
                            onClick={() => onRemove(true)}
                        >
                            <Trash2 className="size-4" />
                            {t('manage.remove_image')}
                        </Button>
                    )}
                    {removed && (
                        <Button
                            type="button"
                            variant="ghost"
                            size="sm"
                            onClick={() => onRemove(false)}
                        >
                            <Undo2 className="size-4" />
                            {t('manage.undo')}
                        </Button>
                    )}
                </div>
            </div>
            {hint && <p className="text-xs text-muted-foreground">{hint}</p>}
            <InputError message={localError ?? error} />
        </div>
    );
}
