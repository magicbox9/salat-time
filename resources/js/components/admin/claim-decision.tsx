import { Check, X } from 'lucide-react';
import { ClaimStatusBadge } from '@/components/claims/claim-status-badge';
import type { AdminClaim } from '@/components/claims/types';
import { useFormatDate } from '@/components/claims/use-format-date';
import { Button } from '@/components/ui/button';
import { useT } from '@/lib/i18n';
import { ConfirmAction } from './confirm-action';
import { Panel } from './panel';

/** Approve / reject a pending request, or show the decision already taken. */
export function ClaimDecision({ claim }: { claim: AdminClaim }) {
    const t = useT();
    const formatDate = useFormatDate();
    const mosqueName = claim.mosque?.name ?? '';
    const claimant = claim.user?.name ?? '';

    if (claim.status !== 'pending') {
        return (
            <Panel title={t('admin.decision_title')}>
                <div className="space-y-3 text-sm">
                    <ClaimStatusBadge status={claim.status} />
                    <p className="text-muted-foreground">
                        {t('admin.decided_by', {
                            name: claim.reviewer?.name ?? '—',
                            date: formatDate(claim.reviewed_at, 'datetime'),
                        })}
                    </p>
                    {claim.review_note && (
                        <div className="rounded-lg bg-muted/60 p-3">
                            <p className="text-xs font-medium text-muted-foreground">
                                {t('admin.note')}
                            </p>
                            <p className="mt-1 whitespace-pre-line">
                                {claim.review_note}
                            </p>
                        </div>
                    )}
                </div>
            </Panel>
        );
    }

    return (
        <Panel
            title={t('admin.decision_title')}
            description={t('admin.decision_intro')}
        >
            <div className="flex flex-col gap-2 sm:flex-row">
                <ConfirmAction
                    trigger={
                        <Button className="sm:flex-1">
                            <Check />
                            {t('admin.approve')}
                        </Button>
                    }
                    title={t('admin.approve_title', {
                        name: claimant,
                        mosque: mosqueName,
                    })}
                    description={t('admin.approve_text')}
                    confirmLabel={t('admin.approve')}
                    method="post"
                    url={`/admin/claims/${claim.id}/approve`}
                    note={{
                        label: t('admin.approve_note_label'),
                        placeholder: t('admin.approve_note_placeholder'),
                    }}
                />
                <ConfirmAction
                    trigger={
                        <Button
                            variant="outline"
                            className="text-destructive hover:text-destructive sm:flex-1"
                        >
                            <X />
                            {t('admin.reject')}
                        </Button>
                    }
                    title={t('admin.reject_title', { mosque: mosqueName })}
                    description={t('admin.reject_text')}
                    confirmLabel={t('admin.reject')}
                    method="post"
                    url={`/admin/claims/${claim.id}/reject`}
                    destructive
                    note={{
                        label: t('admin.reject_note_label'),
                        placeholder: t('admin.reject_note_placeholder'),
                        hint: t('admin.reject_note_hint'),
                        required: true,
                    }}
                />
            </div>
        </Panel>
    );
}
