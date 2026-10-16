import { router } from '@inertiajs/react';
import type { ReactNode } from 'react';
import { useState } from 'react';
import { Textarea } from '@/components/claims/textarea';
import InputError from '@/components/input-error';
import { Button } from '@/components/ui/button';
import {
    Dialog,
    DialogClose,
    DialogContent,
    DialogDescription,
    DialogFooter,
    DialogHeader,
    DialogTitle,
    DialogTrigger,
} from '@/components/ui/dialog';
import { Label } from '@/components/ui/label';
import { Spinner } from '@/components/ui/spinner';
import { useT } from '@/lib/i18n';

type NoteField = {
    label: string;
    placeholder?: string;
    required?: boolean;
    hint?: string;
};

type Props = {
    /** The button that opens the dialog (rendered as the trigger). */
    trigger: ReactNode;
    title: string;
    description?: string;
    confirmLabel: string;
    method: 'post' | 'patch' | 'delete';
    url: string;
    destructive?: boolean;
    /** Ask for a note sent as `note` (e.g. the reason of a rejection). */
    note?: NoteField;
};

const NOTE_MAX = 1000;

/** A confirmation dialog that sends one request (never window.confirm). */
export function ConfirmAction({
    trigger,
    title,
    description,
    confirmLabel,
    method,
    url,
    destructive,
    note,
}: Props) {
    const t = useT();
    const [open, setOpen] = useState(false);
    const [text, setText] = useState('');
    const [error, setError] = useState<string | undefined>();
    const [processing, setProcessing] = useState(false);

    const onOpenChange = (next: boolean) => {
        setOpen(next);

        if (!next) {
            setText('');
            setError(undefined);
        }
    };

    const submit = (event: React.FormEvent) => {
        event.preventDefault();

        if (note?.required && text.trim().length < 3) {
            setError(t('admin.v_note_required'));

            return;
        }

        router.visit(url, {
            method,
            data: note ? { note: text } : {},
            preserveScroll: true,
            onStart: () => setProcessing(true),
            onError: (errors) =>
                setError(errors.note ?? Object.values(errors)[0]),
            onSuccess: () => onOpenChange(false),
            onFinish: () => setProcessing(false),
        });
    };

    return (
        <Dialog open={open} onOpenChange={onOpenChange}>
            <DialogTrigger asChild>{trigger}</DialogTrigger>
            <DialogContent>
                <form onSubmit={submit} className="grid gap-5">
                    <DialogHeader className="text-start sm:text-start">
                        <DialogTitle className="leading-snug">
                            {title}
                        </DialogTitle>
                        {description && (
                            <DialogDescription>{description}</DialogDescription>
                        )}
                    </DialogHeader>

                    {note && (
                        <div className="grid gap-2">
                            <Label htmlFor="confirm-note">{note.label}</Label>
                            <Textarea
                                id="confirm-note"
                                value={text}
                                onChange={(event) =>
                                    setText(event.target.value)
                                }
                                maxLength={NOTE_MAX}
                                rows={4}
                                required={note.required}
                                placeholder={note.placeholder}
                                aria-invalid={error ? true : undefined}
                                autoFocus
                            />
                            {note.hint && (
                                <p className="text-xs text-muted-foreground">
                                    {note.hint}
                                </p>
                            )}
                            <InputError message={error} />
                        </div>
                    )}
                    {!note && <InputError message={error} />}

                    <DialogFooter className="gap-2">
                        <DialogClose asChild>
                            <Button type="button" variant="outline">
                                {t('admin.cancel')}
                            </Button>
                        </DialogClose>
                        <Button
                            type="submit"
                            variant={destructive ? 'destructive' : 'default'}
                            disabled={processing}
                        >
                            {processing && <Spinner />}
                            {confirmLabel}
                        </Button>
                    </DialogFooter>
                </form>
            </DialogContent>
        </Dialog>
    );
}
