import { UserMinus, Users } from 'lucide-react';
import { useFormatDate } from '@/components/claims/use-format-date';
import { Badge } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';
import { useT } from '@/lib/i18n';
import { ConfirmAction } from './confirm-action';
import type { AdminManager } from './types';

type Props = {
    managers: AdminManager[];
    /** When set, each manager can be removed from this mosque. */
    revoke?: { mosqueSlug: string; mosqueName: string };
};

/** People allowed to run a mosque's page. */
export function ManagersList({ managers, revoke }: Props) {
    const t = useT();
    const formatDate = useFormatDate();

    if (managers.length === 0) {
        return (
            <p className="flex items-center gap-2 text-sm text-muted-foreground">
                <Users className="size-4" aria-hidden />
                {t('admin.no_managers')}
            </p>
        );
    }

    return (
        <ul className="divide-y">
            {managers.map((manager) => (
                <li
                    key={manager.id}
                    className="flex flex-wrap items-center gap-3 py-3 first:pt-0 last:pb-0"
                >
                    <div className="min-w-0 flex-1">
                        <div className="flex flex-wrap items-center gap-2">
                            <span className="font-medium">{manager.name}</span>
                            <Badge variant="secondary" className="rounded-full">
                                {t(
                                    manager.role === 'owner'
                                        ? 'admin.role_owner'
                                        : 'admin.role_editor',
                                )}
                            </Badge>
                        </div>
                        <p className="truncate text-xs text-muted-foreground">
                            <span dir="ltr">{manager.email}</span>
                        </p>
                        <p className="text-xs text-muted-foreground">
                            {manager.granted_by
                                ? t('admin.manager_since_by', {
                                      date: formatDate(manager.since),
                                      name: manager.granted_by,
                                  })
                                : t('admin.manager_since', {
                                      date: formatDate(manager.since),
                                  })}
                        </p>
                    </div>
                    {revoke && (
                        <ConfirmAction
                            trigger={
                                <Button
                                    variant="ghost"
                                    size="sm"
                                    className="text-destructive hover:text-destructive"
                                >
                                    <UserMinus />
                                    {t('admin.revoke')}
                                </Button>
                            }
                            title={t('admin.revoke_manager_title', {
                                name: manager.name,
                            })}
                            description={t('admin.revoke_manager_text', {
                                mosque: revoke.mosqueName,
                            })}
                            confirmLabel={t('admin.revoke')}
                            method="delete"
                            url={`/admin/mosques/${revoke.mosqueSlug}/managers/${manager.id}`}
                            destructive
                        />
                    )}
                </li>
            ))}
        </ul>
    );
}
