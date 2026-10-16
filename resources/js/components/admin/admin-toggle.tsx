import { Shield, ShieldOff } from 'lucide-react';
import type { ReactNode } from 'react';
import { useId } from 'react';
import { Button } from '@/components/ui/button';
import { useT } from '@/lib/i18n';
import { ConfirmAction } from './confirm-action';
import type { AdminUserRow } from './types';

/**
 * A button that cannot be used, with the reason. A disabled button gets no
 * hover events, so the reason sits on a wrapper (mouse) and is read out with
 * the button (screen readers).
 */
function Unavailable({
    reason,
    children,
}: {
    reason: string;
    children: ReactNode;
}) {
    const id = useId();

    return (
        <span className="inline-flex" title={reason}>
            <Button variant="outline" size="sm" disabled aria-describedby={id}>
                {children}
            </Button>
            <span id={id} className="sr-only">
                {reason}
            </span>
        </span>
    );
}

/** Grant or withdraw platform admin rights (never on yourself, never the last admin). */
export function AdminToggle({
    user,
    adminCount,
}: {
    user: AdminUserRow;
    adminCount: number;
}) {
    const t = useT();
    const url = `/admin/users/${user.id}/admin`;

    if (user.is_admin) {
        const label = (
            <>
                <ShieldOff />
                {t('admin.revoke_admin')}
            </>
        );

        if (user.is_self || adminCount <= 1) {
            return (
                <Unavailable
                    reason={t(
                        user.is_self
                            ? 'admin.error_self_admin'
                            : 'admin.error_last_admin',
                    )}
                >
                    {label}
                </Unavailable>
            );
        }

        return (
            <ConfirmAction
                trigger={
                    <Button
                        variant="outline"
                        size="sm"
                        className="text-destructive hover:text-destructive"
                    >
                        {label}
                    </Button>
                }
                title={t('admin.revoke_admin_title', { name: user.name })}
                description={t('admin.revoke_admin_text')}
                confirmLabel={t('admin.revoke_admin')}
                method="delete"
                url={url}
                destructive
            />
        );
    }

    const label = (
        <>
            <Shield />
            {t('admin.grant_admin')}
        </>
    );

    if (!user.verified) {
        return (
            <Unavailable reason={t('admin.error_unverified_admin')}>
                {label}
            </Unavailable>
        );
    }

    return (
        <ConfirmAction
            trigger={
                <Button variant="outline" size="sm">
                    {label}
                </Button>
            }
            title={t('admin.grant_admin_title', { name: user.name })}
            description={t('admin.grant_admin_text')}
            confirmLabel={t('admin.grant_admin')}
            method="post"
            url={url}
        />
    );
}
