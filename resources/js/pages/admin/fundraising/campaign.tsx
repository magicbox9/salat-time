import { Head, Link } from '@inertiajs/react';
import {
    Check,
    CreditCard,
    ExternalLink,
    Flag,
    Landmark,
    X,
} from 'lucide-react';
import { BackLink, AdminShell } from '@/components/admin/admin-shell';
import { ConfirmAction } from '@/components/admin/confirm-action';
import { InfoList, InfoRow, Panel } from '@/components/admin/panel';
import type { AdminPageProps } from '@/components/admin/types';
import { useFormatDate } from '@/components/claims/use-format-date';
import { KindBadge, StateBadge } from '@/components/fundraising/badges';
import { CampaignCover } from '@/components/fundraising/campaign-cover';
import { useMoney } from '@/components/fundraising/format';
import { ProblemsNotice } from '@/components/fundraising/problems-notice';
import type {
    AvailableMethods,
    CampaignDetail,
    EligibilityProblem,
} from '@/components/fundraising/types';
import { MarkdownContent } from '@/components/markdown-content';
import { Button } from '@/components/ui/button';
import { useT } from '@/lib/i18n';

type Props = AdminPageProps & {
    campaign: CampaignDetail & {
        review_note: string | null;
        reviewed_by: string | null;
        reviewed_at: string | null;
        allow_paypal: boolean;
        allow_bank: boolean;
        /** The reviewed content's version, sent back with the approval. */
        version: string;
    };
    problems: EligibilityProblem[];
    allowable: AvailableMethods;
};

/** Reviewing one campaign: the page as donors would see it, the checks, and the decision. */
export default function AdminCampaign({
    campaign,
    problems,
    allowable,
    pendingClaimsCount,
}: Props) {
    const t = useT();
    const money = useMoney();
    const formatDate = useFormatDate();
    const url = `/admin/fundraising/campaigns/${campaign.slug}`;
    const mosque = campaign.mosque;

    return (
        <>
            <Head title={campaign.title} />
            <AdminShell
                title={campaign.title}
                description={
                    mosque
                        ? `${mosque.name}${mosque.city ? ` · ${mosque.city}` : ''}`
                        : undefined
                }
                pendingClaimsCount={pendingClaimsCount}
                back={
                    <BackLink
                        href="/admin/fundraising/campaigns"
                        label={t('fundraising.admin_campaigns')}
                    />
                }
                actions={
                    <>
                        {campaign.status === 'pending' && (
                            <>
                                <ConfirmAction
                                    trigger={
                                        <Button disabled={problems.length > 0}>
                                            <Check
                                                className="size-4"
                                                aria-hidden
                                            />
                                            {t('fundraising.admin_approve')}
                                        </Button>
                                    }
                                    title={t('fundraising.admin_approve_title')}
                                    description={t(
                                        'fundraising.admin_approve_body',
                                    )}
                                    confirmLabel={t(
                                        'fundraising.admin_approve',
                                    )}
                                    method="post"
                                    url={`${url}/approve?version=${encodeURIComponent(campaign.version)}`}
                                    note={{
                                        label: t(
                                            'fundraising.admin_note_optional',
                                        ),
                                    }}
                                />
                                <ConfirmAction
                                    trigger={
                                        <Button variant="outline">
                                            <X className="size-4" aria-hidden />
                                            {t('fundraising.admin_reject')}
                                        </Button>
                                    }
                                    title={t('fundraising.admin_reject_title')}
                                    description={t(
                                        'fundraising.admin_reject_body',
                                    )}
                                    confirmLabel={t('fundraising.admin_reject')}
                                    method="post"
                                    url={`${url}/reject`}
                                    destructive
                                    note={{
                                        label: t('fundraising.admin_note'),
                                        required: true,
                                        hint: t('fundraising.admin_note_hint'),
                                    }}
                                />
                            </>
                        )}
                        {campaign.status === 'active' && (
                            <ConfirmAction
                                trigger={
                                    <Button variant="outline">
                                        <Flag className="size-4" aria-hidden />
                                        {t('fundraising.admin_close')}
                                    </Button>
                                }
                                title={t('fundraising.admin_close_title')}
                                description={t('fundraising.admin_close_body')}
                                confirmLabel={t('fundraising.admin_close')}
                                method="post"
                                url={`${url}/close`}
                                destructive
                                note={{
                                    label: t('fundraising.admin_note_optional'),
                                }}
                            />
                        )}
                        <Button asChild variant="ghost">
                            <Link href={`/campaigns/${campaign.slug}`}>
                                <ExternalLink className="size-4" aria-hidden />
                                {t('fundraising.preview')}
                            </Link>
                        </Button>
                    </>
                }
            >
                {campaign.status === 'pending' && mosque && (
                    <ProblemsNotice
                        problems={problems}
                        mosqueSlug={mosque.slug}
                        title={t('fundraising.admin_problems_title')}
                    />
                )}

                <div className="grid gap-6 lg:grid-cols-[minmax(0,1fr)_320px]">
                    <Panel title={t('fundraising.admin_as_donors_see')}>
                        <div className="space-y-4">
                            <CampaignCover
                                url={campaign.cover_url}
                                className="aspect-[2/1] rounded-xl"
                            />
                            <div className="flex flex-wrap gap-2">
                                <StateBadge state={campaign.state} />
                                <KindBadge
                                    kind={campaign.kind}
                                    className="px-2 py-0.5"
                                />
                            </div>
                            <p className="text-lg text-muted-foreground">
                                {campaign.summary}
                            </p>
                            <MarkdownContent html={campaign.story_html} />
                        </div>
                    </Panel>

                    <div className="space-y-6">
                        <Panel title={t('fundraising.admin_details')}>
                            <InfoList>
                                <InfoRow label={t('fundraising.goal')}>
                                    <span dir="ltr">
                                        {money(
                                            campaign.goal,
                                            campaign.currency,
                                        )}
                                    </span>
                                </InfoRow>
                                <InfoRow label={t('fundraising.raised')}>
                                    <span dir="ltr">
                                        {money(
                                            campaign.raised,
                                            campaign.currency,
                                        )}
                                    </span>
                                </InfoRow>
                                <InfoRow
                                    label={t('fundraising.field_starts_on')}
                                >
                                    {formatDate(campaign.starts_at)}
                                </InfoRow>
                                <InfoRow label={t('fundraising.field_ends_on')}>
                                    {formatDate(campaign.ends_at)}
                                </InfoRow>
                                <InfoRow
                                    label={t('fundraising.section_methods')}
                                >
                                    <span className="flex flex-col gap-1">
                                        {campaign.allow_paypal && (
                                            <span className="inline-flex items-center gap-1.5">
                                                <CreditCard
                                                    className="size-4"
                                                    aria-hidden
                                                />
                                                {t('fundraising.method_paypal')}{' '}
                                                —{' '}
                                                {allowable.paypal
                                                    ? t('fundraising.verified')
                                                    : t(
                                                          'fundraising.not_verified',
                                                      )}
                                            </span>
                                        )}
                                        {campaign.allow_bank && (
                                            <span className="inline-flex items-center gap-1.5">
                                                <Landmark
                                                    className="size-4"
                                                    aria-hidden
                                                />
                                                {t('fundraising.method_bank')} —{' '}
                                                {allowable.bank
                                                    ? t('fundraising.verified')
                                                    : t(
                                                          'fundraising.not_verified',
                                                      )}
                                            </span>
                                        )}
                                    </span>
                                </InfoRow>
                                <InfoRow
                                    label={t('fundraising.show_donor_names')}
                                >
                                    {campaign.show_donor_names
                                        ? t('fundraising.yes')
                                        : t('fundraising.no')}
                                </InfoRow>
                                {campaign.reviewed_by && (
                                    <InfoRow
                                        label={t('fundraising.admin_reviewed')}
                                    >
                                        {campaign.reviewed_by} ·{' '}
                                        {formatDate(
                                            campaign.reviewed_at,
                                            'datetime',
                                        )}
                                    </InfoRow>
                                )}
                                {campaign.review_note && (
                                    <InfoRow
                                        label={t('fundraising.admin_note')}
                                    >
                                        {campaign.review_note}
                                    </InfoRow>
                                )}
                            </InfoList>
                        </Panel>
                        {mosque && (
                            <Button
                                asChild
                                variant="outline"
                                className="w-full"
                            >
                                <Link href={`/admin/mosques/${mosque.slug}`}>
                                    {t('fundraising.admin_open_mosque')}
                                </Link>
                            </Button>
                        )}
                    </div>
                </div>
            </AdminShell>
        </>
    );
}
