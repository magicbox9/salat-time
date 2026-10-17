import { Eye, EyeOff } from 'lucide-react';
import { useState } from 'react';
import { api, errorMessage } from '@/components/mosque/api';
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
import { Spinner } from '@/components/ui/spinner';
import { useT } from '@/lib/i18n';

/**
 * The masked IBAN, and on an explicit, confirmed request the full one
 * (the server logs who asked). Hidden again with one click.
 */
export function RevealIban({
    payoutId,
    masked,
}: {
    payoutId: number;
    masked: string;
}) {
    const t = useT();
    const [iban, setIban] = useState<string | null>(null);
    const [open, setOpen] = useState(false);
    const [loading, setLoading] = useState(false);
    const [error, setError] = useState<string | null>(null);

    const reveal = () => {
        setLoading(true);
        setError(null);
        api<{ iban: string }>(
            'POST',
            `/admin/fundraising/payouts/${payoutId}/reveal`,
        )
            .then((data) => {
                setIban(data.iban);
                setOpen(false);
            })
            .catch((failure) => setError(errorMessage(failure, t)))
            .finally(() => setLoading(false));
    };

    if (iban) {
        return (
            <span className="inline-flex flex-wrap items-center gap-2">
                <span className="font-mono font-semibold" dir="ltr">
                    {iban}
                </span>
                <Button
                    type="button"
                    variant="ghost"
                    size="sm"
                    onClick={() => setIban(null)}
                >
                    <EyeOff className="size-4" aria-hidden />
                    {t('fundraising.admin_hide')}
                </Button>
            </span>
        );
    }

    return (
        <span className="inline-flex flex-wrap items-center gap-2">
            <span className="font-mono" dir="ltr">
                {masked}
            </span>
            <Dialog open={open} onOpenChange={setOpen}>
                <DialogTrigger asChild>
                    <Button type="button" variant="outline" size="sm">
                        <Eye className="size-4" aria-hidden />
                        {t('fundraising.admin_reveal')}
                    </Button>
                </DialogTrigger>
                <DialogContent>
                    <DialogTitle>
                        {t('fundraising.admin_reveal_title')}
                    </DialogTitle>
                    <DialogDescription>
                        {t('fundraising.admin_reveal_body')}
                    </DialogDescription>
                    {error && (
                        <p className="text-sm text-destructive-foreground">
                            {error}
                        </p>
                    )}
                    <DialogFooter className="gap-2">
                        <DialogClose asChild>
                            <Button variant="outline">
                                {t('fundraising.cancel')}
                            </Button>
                        </DialogClose>
                        <Button onClick={reveal} disabled={loading}>
                            {loading && <Spinner />}
                            {t('fundraising.admin_reveal')}
                        </Button>
                    </DialogFooter>
                </DialogContent>
            </Dialog>
        </span>
    );
}
