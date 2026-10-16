import { router, usePage } from '@inertiajs/react';
import { Building2, ShieldCheck, User } from 'lucide-react';
import { useT } from '@/lib/i18n';

const ICONS = { admin: ShieldCheck, manager: Building2, user: User } as const;

/**
 * Development only: one-click sign-in as the seeded test accounts
 * (config/devlogin.php). Renders nothing unless the server offers accounts.
 */
export default function DevLoginPanel() {
    const { devAccounts } = usePage<{ devAccounts?: string[] }>().props;
    const t = useT();

    if (!devAccounts?.length) {
        return null;
    }

    return (
        <div className="mb-2 rounded-xl border border-dashed border-gold/60 bg-gold/5 p-3">
            <p className="mb-2 text-xs font-medium tracking-wide text-gold uppercase">
                {t('devlogin.title')}
            </p>
            <div className="grid gap-2">
                {devAccounts.map((account) => {
                    const Icon = ICONS[account as keyof typeof ICONS] ?? User;

                    return (
                        <button
                            key={account}
                            type="button"
                            onClick={() => router.post(`/dev-login/${account}`)}
                            className="flex items-center gap-3 rounded-lg border bg-card px-3 py-2 text-start transition-colors hover:border-primary/60 hover:bg-accent"
                            data-test={`dev-login-${account}`}
                        >
                            <Icon className="size-4 shrink-0 text-primary" />
                            <span className="flex flex-col">
                                <span className="text-sm font-medium">
                                    {t(`devlogin.${account}`)}
                                </span>
                                <span className="text-xs text-muted-foreground">
                                    {t(`devlogin.${account}_hint`)}
                                </span>
                            </span>
                        </button>
                    );
                })}
            </div>
        </div>
    );
}
