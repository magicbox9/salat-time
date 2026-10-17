import { FileText, FileUp, Trash2, Undo2 } from 'lucide-react';
import { useId, useRef, useState } from 'react';
import InputError from '@/components/input-error';
import { Button } from '@/components/ui/button';
import { useT } from '@/lib/i18n';

type Props = {
    current: { name: string; url: string } | null;
    file: File | null;
    removed: boolean;
    maxMb: number;
    onFile: (file: File | null) => void;
    onRemove: (removed: boolean) => void;
    error?: string;
};

/** A PDF attached to the post (khutbah text, programme): choose, replace or remove. */
export function AttachmentField({
    current,
    file,
    removed,
    maxMb,
    onFile,
    onRemove,
    error,
}: Props) {
    const t = useT();
    const id = useId();
    const input = useRef<HTMLInputElement>(null);
    const [localError, setLocalError] = useState<string | null>(null);
    const shown = file ? file.name : removed ? null : (current?.name ?? null);

    const choose = (picked: File | undefined) => {
        if (!picked) {
            return;
        }

        if (
            picked.type !== 'application/pdf' &&
            !picked.name.toLowerCase().endsWith('.pdf')
        ) {
            setLocalError(t('manage.attachment_type'));

            return;
        }

        if (picked.size > maxMb * 1024 * 1024) {
            setLocalError(t('manage.attachment_too_big', { max: maxMb }));

            return;
        }

        setLocalError(null);
        onRemove(false);
        onFile(picked);
    };

    return (
        <div className="grid gap-2">
            <label htmlFor={id} className="text-sm font-medium">
                {t('manage.attachment')}
            </label>
            <div className="flex flex-col gap-3 rounded-xl border border-dashed p-3 sm:flex-row sm:items-center">
                <span className="flex min-w-0 flex-1 items-center gap-3">
                    <span className="flex size-10 shrink-0 items-center justify-center rounded-lg bg-red-500/10 text-red-700 dark:text-red-300">
                        <FileText className="size-5" aria-hidden />
                    </span>
                    <span className="min-w-0 truncate text-sm" dir="auto">
                        {shown ?? (
                            <span className="text-muted-foreground">
                                {t('manage.attachment_none')}
                            </span>
                        )}
                    </span>
                </span>
                <div className="flex flex-wrap gap-2">
                    <input
                        ref={input}
                        id={id}
                        type="file"
                        accept="application/pdf,.pdf"
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
                        <FileUp className="size-4" aria-hidden />
                        {shown
                            ? t('manage.replace_file')
                            : t('manage.choose_pdf')}
                    </Button>
                    {file && (
                        <Button
                            type="button"
                            variant="ghost"
                            size="sm"
                            onClick={() => onFile(null)}
                        >
                            <Undo2 className="size-4" aria-hidden />
                            {t('manage.undo')}
                        </Button>
                    )}
                    {!file && current && !removed && (
                        <Button
                            type="button"
                            variant="ghost"
                            size="sm"
                            onClick={() => onRemove(true)}
                        >
                            <Trash2 className="size-4" aria-hidden />
                            {t('manage.remove_file')}
                        </Button>
                    )}
                    {removed && (
                        <Button
                            type="button"
                            variant="ghost"
                            size="sm"
                            onClick={() => onRemove(false)}
                        >
                            <Undo2 className="size-4" aria-hidden />
                            {t('manage.undo')}
                        </Button>
                    )}
                </div>
            </div>
            <p className="text-xs text-muted-foreground">
                {t('manage.attachment_hint', { max: maxMb })}
            </p>
            <InputError message={localError ?? error} />
        </div>
    );
}
