import { router } from '@inertiajs/react';
import { Trash2 } from 'lucide-react';
import { useState } from 'react';
import { Button } from '@/components/ui/button';
import {
    Dialog,
    DialogClose,
    DialogContent,
    DialogDescription,
    DialogFooter,
    DialogTitle,
    DialogTrigger,
} from '@/components/ui/dialog';
import { useT } from '@/lib/i18n';

type Props = {
    url: string;
    title: string;
    description: string;
    label?: string;
    iconOnly?: boolean;
};

/** A delete button that asks first, then sends DELETE through Inertia. */
export function ConfirmDelete({
    url,
    title,
    description,
    label,
    iconOnly = false,
}: Props) {
    const t = useT();
    const [open, setOpen] = useState(false);
    const [processing, setProcessing] = useState(false);

    return (
        <Dialog open={open} onOpenChange={setOpen}>
            <DialogTrigger asChild>
                <Button
                    variant="ghost"
                    size={iconOnly ? 'icon' : 'sm'}
                    className="text-muted-foreground hover:text-destructive"
                    aria-label={label ?? t('manage.delete')}
                >
                    <Trash2 className="size-4" />
                    {!iconOnly && (label ?? t('manage.delete'))}
                </Button>
            </DialogTrigger>
            <DialogContent>
                <DialogTitle>{title}</DialogTitle>
                <DialogDescription>{description}</DialogDescription>
                <DialogFooter className="gap-2">
                    <DialogClose asChild>
                        <Button variant="secondary">
                            {t('manage.cancel')}
                        </Button>
                    </DialogClose>
                    <Button
                        variant="destructive"
                        disabled={processing}
                        onClick={() =>
                            router.delete(url, {
                                preserveScroll: true,
                                onStart: () => setProcessing(true),
                                onFinish: () => {
                                    setProcessing(false);
                                    setOpen(false);
                                },
                            })
                        }
                    >
                        {t('manage.delete')}
                    </Button>
                </DialogFooter>
            </DialogContent>
        </Dialog>
    );
}
