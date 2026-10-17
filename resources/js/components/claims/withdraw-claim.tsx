import { router } from '@inertiajs/react';
import { Undo2 } from 'lucide-react';
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

/** "Withdraw request" for a claim still waiting for review, after a confirmation. */
export function WithdrawClaim({
    claimId,
    mosqueName,
}: {
    claimId: number;
    mosqueName: string;
}) {
    const t = useT();
    const [busy, setBusy] = useState(false);

    const withdraw = () =>
        router.delete(`/me/claims/${claimId}`, {
            preserveScroll: true,
            onStart: () => setBusy(true),
            onFinish: () => setBusy(false),
        });

    return (
        <Dialog>
            <DialogTrigger asChild>
                <Button size="sm" variant="outline">
                    <Undo2 />
                    {t('claims.withdraw')}
                </Button>
            </DialogTrigger>
            <DialogContent>
                <DialogTitle>{t('claims.withdraw_title')}</DialogTitle>
                <DialogDescription>
                    {t('claims.withdraw_text', { mosque: mosqueName })}
                </DialogDescription>
                <DialogFooter className="gap-2">
                    <DialogClose asChild>
                        <Button variant="secondary">
                            {t('claims.withdraw_keep')}
                        </Button>
                    </DialogClose>
                    <Button
                        variant="destructive"
                        disabled={busy}
                        onClick={withdraw}
                    >
                        {t('claims.withdraw')}
                    </Button>
                </DialogFooter>
            </DialogContent>
        </Dialog>
    );
}
