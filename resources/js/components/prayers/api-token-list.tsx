import { router, usePage } from '@inertiajs/react';
import { KeyRound, Smartphone } from 'lucide-react';
import { useState } from 'react';
import { Button } from '@/components/ui/button';
import {
    Dialog,
    DialogClose,
    DialogContent,
    DialogDescription,
    DialogFooter,
    DialogHeader,
    DialogTitle,
} from '@/components/ui/dialog';
import { intlLocale, useT } from '@/lib/i18n';

export type ApiToken = {
    id: number;
    name: string;
    last_used_at: string | null;
    expires_at: string | null;
    created_at: string | null;
    expired: boolean;
};

/** The person's companion-app tokens, each revocable. */
export function ApiTokenList({ tokens }: { tokens: ApiToken[] }) {
    const t = useT();
    const { locale } = usePage().props;
    const [revoking, setRevoking] = useState<ApiToken | null>(null);
    const [busy, setBusy] = useState(false);
    const date = (iso: string | null) =>
        iso
            ? new Intl.DateTimeFormat(intlLocale(locale), {
                  dateStyle: 'medium',
              }).format(new Date(iso))
            : '—';

    const revoke = () => {
        if (!revoking) {
            return;
        }

        router.delete(`/settings/api-tokens/${revoking.id}`, {
            preserveScroll: true,
            onStart: () => setBusy(true),
            onFinish: () => {
                setBusy(false);
                setRevoking(null);
            },
        });
    };

    if (tokens.length === 0) {
        return (
            <div className="rounded-xl border border-dashed p-8 text-center">
                <div className="mx-auto mb-3 flex size-12 items-center justify-center rounded-2xl bg-muted">
                    <Smartphone className="size-6 text-muted-foreground" />
                </div>
                <p className="font-medium">{t('prayers.tokens_empty_title')}</p>
                <p className="mt-1 text-sm text-muted-foreground">
                    {t('prayers.tokens_empty_text')}
                </p>
            </div>
        );
    }

    return (
        <>
            <ul className="divide-y overflow-hidden rounded-xl border">
                {tokens.map((token) => (
                    <li
                        key={token.id}
                        className="flex flex-wrap items-center gap-3 p-4"
                    >
                        <KeyRound className="size-5 shrink-0 text-primary" />
                        <div className="min-w-0 flex-1">
                            <p className="truncate font-medium">{token.name}</p>
                            <p className="text-xs text-muted-foreground">
                                {t('prayers.tokens_created_on', {
                                    date: date(token.created_at),
                                })}
                                {' · '}
                                {token.last_used_at
                                    ? t('prayers.tokens_last_used', {
                                          date: date(token.last_used_at),
                                      })
                                    : t('prayers.tokens_never_used')}
                                {' · '}
                                {token.expired
                                    ? t('prayers.tokens_expired')
                                    : t('prayers.tokens_expires', {
                                          date: date(token.expires_at),
                                      })}
                            </p>
                        </div>
                        <Button
                            variant="outline"
                            size="sm"
                            onClick={() => setRevoking(token)}
                        >
                            {t('prayers.tokens_revoke')}
                        </Button>
                    </li>
                ))}
            </ul>

            <Dialog
                open={revoking !== null}
                onOpenChange={(open) => !open && setRevoking(null)}
            >
                <DialogContent className="sm:max-w-md">
                    <DialogHeader>
                        <DialogTitle>
                            {t('prayers.tokens_revoke_title', {
                                name: revoking?.name ?? '',
                            })}
                        </DialogTitle>
                        <DialogDescription>
                            {t('prayers.tokens_revoke_text')}
                        </DialogDescription>
                    </DialogHeader>
                    <DialogFooter className="gap-2">
                        <DialogClose asChild>
                            <Button variant="outline">
                                {t('prayers.cancel')}
                            </Button>
                        </DialogClose>
                        <Button
                            variant="destructive"
                            onClick={revoke}
                            disabled={busy}
                        >
                            {t('prayers.tokens_revoke')}
                        </Button>
                    </DialogFooter>
                </DialogContent>
            </Dialog>
        </>
    );
}
