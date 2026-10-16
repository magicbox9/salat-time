import { BadgeCheck, ShieldOff } from 'lucide-react';
import { useFormatDate } from '@/components/claims/use-format-date';
import { Button } from '@/components/ui/button';
import { useT } from '@/lib/i18n';
import { ConfirmAction } from './confirm-action';
import { Panel } from './panel';

type Props = {
    slug: string;
    name: string;
    verifiedAt: string | null;
};

/** Documents and finances checked: a prerequisite for any future fundraising. */
export function VerificationPanel({ slug, name, verifiedAt }: Props) {
    const t = useT();
    const formatDate = useFormatDate();
    const url = `/admin/mosques/${slug}/verify`;

    return (
        <Panel title={t('admin.verification')}>
            {verifiedAt ? (
                <div className="space-y-4">
                    <p className="flex items-center gap-2 text-sm font-medium text-primary">
                        <BadgeCheck className="size-4" aria-hidden />
                        {t('admin.verified_on', {
                            date: formatDate(verifiedAt),
                        })}
                    </p>
                    <ConfirmAction
                        trigger={
                            <Button
                                variant="outline"
                                size="sm"
                                className="text-destructive hover:text-destructive"
                            >
                                <ShieldOff />
                                {t('admin.unverify')}
                            </Button>
                        }
                        title={t('admin.unverify_title', { name })}
                        description={t('admin.unverify_text')}
                        confirmLabel={t('admin.unverify')}
                        method="delete"
                        url={url}
                        destructive
                    />
                </div>
            ) : (
                <div className="space-y-4">
                    <p className="text-sm text-muted-foreground">
                        {t('admin.verification_text')}
                    </p>
                    <ConfirmAction
                        trigger={
                            <Button size="sm">
                                <BadgeCheck />
                                {t('admin.verify')}
                            </Button>
                        }
                        title={t('admin.verify_title', { name })}
                        description={t('admin.verify_text')}
                        confirmLabel={t('admin.verify')}
                        method="post"
                        url={url}
                    />
                </div>
            )}
        </Panel>
    );
}
