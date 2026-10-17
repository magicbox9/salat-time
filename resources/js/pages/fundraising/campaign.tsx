import { Link } from '@inertiajs/react';
import { ArrowLeft, ExternalLink, Flag, PencilLine, Send } from 'lucide-react';
import { ConfirmAction } from '@/components/admin/confirm-action';
import { KindBadge, StateBadge } from '@/components/fundraising/badges';
import { CampaignCover } from '@/components/fundraising/campaign-cover';
import { DonationRows } from '@/components/fundraising/donation-rows';
import { useCount, useMoney } from '@/components/fundraising/format';
import { FundraisingNav } from '@/components/fundraising/manage-nav';
import { ProblemsNotice } from '@/components/fundraising/problems-notice';
import { ProgressBar } from '@/components/fundraising/progress-bar';
import type {
    CampaignCardData,
    CampaignUpdateData,
    EligibilityProblem,
    ManagedDonation,
} from '@/components/fundraising/types';
import { UpdateForm } from '@/components/fundraising/update-form';
import { UpdatesTimeline } from '@/components/fundraising/updates-timeline';
import { ConfirmDelete } from '@/components/manage/confirm-delete';
import { FormSection } from '@/components/manage/fields';
import { ManageLayout } from '@/components/manage/manage-layout';
import { Button } from '@/components/ui/button';
import { useT } from '@/lib/i18n';
import type { MosqueSummary } from '@/types/mosque';

type Props = {
    mosque: MosqueSummary;
    campaign: CampaignCardData & { review_note: string | null };
    updates: CampaignUpdateData[];
    donations: ManagedDonation[];
    problems: EligibilityProblem[];
};

/** One campaign for its mosque: status, figures, review, news and the latest gifts. */
export default function ManageCampaign({
    mosque,
    campaign,
    updates,
    donations,
    problems,
}: Props) {
    const t = useT();
    const money = useMoney();
    const count = useCount();
    const base = `/manage/${mosque.slug}/campaigns/${campaign.slug}`;
    const submittable = ['draft', 'rejected'].includes(campaign.status);
    const editable = ['draft', 'pending', 'rejected', 'active'].includes(
        campaign.status,
    );
    const deletable =
        ['draft', 'rejected', 'pending'].includes(campaign.status) &&
        campaign.donors_count === 0 &&
        campaign.pledged === 0;

    return (
        <ManageLayout mosque={mosque} title={campaign.title}>
            <FundraisingNav mosqueSlug={mosque.slug} />

            <Link
                href={`/manage/${mosque.slug}/campaigns`}
                className="inline-flex items-center gap-1.5 text-sm text-muted-foreground hover:text-foreground"
            >
                <ArrowLeft className="size-4 rtl:rotate-180" aria-hidden />
                {t('fundraising.all_my_campaigns')}
            </Link>

            <section className="overflow-hidden rounded-3xl border bg-card shadow-xs">
                <CampaignCover
                    url={campaign.cover_url}
                    className="h-32 sm:h-44"
                />
                <div className="space-y-5 p-5 sm:p-6">
                    <div className="flex flex-wrap items-center gap-2">
                        <StateBadge state={campaign.state} />
                        <KindBadge
                            kind={campaign.kind}
                            className="px-2 py-0.5"
                        />
                    </div>
                    <p className="text-muted-foreground">
                        {t(`fundraising.status_help_${campaign.status}`)}
                    </p>

                    {campaign.status === 'rejected' && campaign.review_note && (
                        <p className="rounded-xl border border-red-500/30 bg-red-500/10 px-4 py-3 text-sm">
                            {t('fundraising.review_note', {
                                note: campaign.review_note,
                            })}
                        </p>
                    )}

                    <div className="space-y-2">
                        <ProgressBar
                            percent={campaign.percent}
                            pledgedPercent={
                                campaign.goal
                                    ? (campaign.pledged * 100) / campaign.goal
                                    : 0
                            }
                            size="lg"
                        />
                        <dl className="grid grid-cols-2 gap-3 text-sm sm:grid-cols-4">
                            {[
                                [
                                    t('fundraising.raised'),
                                    money(campaign.raised, campaign.currency),
                                ],
                                [
                                    t('fundraising.goal'),
                                    money(campaign.goal, campaign.currency),
                                ],
                                [
                                    t('fundraising.pledged'),
                                    money(campaign.pledged, campaign.currency),
                                ],
                                [
                                    t('fundraising.donors'),
                                    count(campaign.donors_count),
                                ],
                            ].map(([label, value]) => (
                                <div
                                    key={label}
                                    className="rounded-xl bg-muted/60 px-3 py-2"
                                >
                                    <dt className="text-xs text-muted-foreground">
                                        {label}
                                    </dt>
                                    <dd className="font-semibold" dir="ltr">
                                        <span className="inline-block">
                                            {value}
                                        </span>
                                    </dd>
                                </div>
                            ))}
                        </dl>
                    </div>

                    <div className="flex flex-wrap gap-2">
                        {submittable && (
                            <ConfirmAction
                                trigger={
                                    <Button disabled={problems.length > 0}>
                                        <Send className="size-4" aria-hidden />
                                        {t('fundraising.submit_review')}
                                    </Button>
                                }
                                title={t('fundraising.submit_title')}
                                description={t('fundraising.submit_body')}
                                confirmLabel={t('fundraising.submit_review')}
                                method="post"
                                url={`${base}/submit`}
                            />
                        )}
                        {editable && (
                            <Button asChild variant="outline">
                                <Link href={`${base}/edit`}>
                                    <PencilLine
                                        className="size-4"
                                        aria-hidden
                                    />
                                    {t('fundraising.edit')}
                                </Link>
                            </Button>
                        )}
                        <Button asChild variant="outline">
                            <Link href={`/campaigns/${campaign.slug}`}>
                                <ExternalLink className="size-4" aria-hidden />
                                {campaign.status === 'active'
                                    ? t('fundraising.view_public')
                                    : t('fundraising.preview')}
                            </Link>
                        </Button>
                        {campaign.status === 'active' && (
                            <ConfirmAction
                                trigger={
                                    <Button variant="ghost">
                                        <Flag className="size-4" aria-hidden />
                                        {t('fundraising.close_campaign')}
                                    </Button>
                                }
                                title={t('fundraising.close_title')}
                                description={t('fundraising.close_body')}
                                confirmLabel={t('fundraising.close_campaign')}
                                method="post"
                                url={`${base}/close`}
                                destructive
                            />
                        )}
                        {deletable && (
                            <ConfirmDelete
                                url={base}
                                title={t('fundraising.delete_title')}
                                description={t('fundraising.delete_body', {
                                    title: campaign.title,
                                })}
                            />
                        )}
                    </div>
                </div>
            </section>

            {submittable && (
                <ProblemsNotice problems={problems} mosqueSlug={mosque.slug} />
            )}

            <FormSection
                title={t('fundraising.updates_title')}
                description={t('fundraising.updates_intro')}
            >
                {campaign.status !== 'draft' && (
                    <UpdateForm url={`${base}/updates`} />
                )}
                <UpdatesTimeline
                    updates={updates}
                    action={(update) => (
                        <ConfirmDelete
                            url={`${base}/updates/${update.id}`}
                            title={t('fundraising.delete_update_title')}
                            description={t('fundraising.delete_update_body', {
                                title: update.title,
                            })}
                            iconOnly
                        />
                    )}
                />
                {updates.length === 0 && (
                    <p className="text-sm text-muted-foreground">
                        {t('fundraising.no_updates')}
                    </p>
                )}
            </FormSection>

            <section className="space-y-3">
                <div className="flex items-center justify-between gap-3">
                    <h2 className="text-lg font-semibold">
                        {t('fundraising.latest_donations')}
                    </h2>
                    <Button asChild variant="link" size="sm">
                        <Link
                            href={`/manage/${mosque.slug}/donations?campaign=${campaign.slug}`}
                        >
                            {t('fundraising.see_all')}
                        </Link>
                    </Button>
                </div>
                {donations.length === 0 ? (
                    <p className="rounded-2xl border border-dashed px-5 py-8 text-center text-sm text-muted-foreground">
                        {t('fundraising.no_donations')}
                    </p>
                ) : (
                    <DonationRows
                        donations={donations}
                        mosqueSlug={mosque.slug}
                        showCampaign={false}
                    />
                )}
            </section>
        </ManageLayout>
    );
}
