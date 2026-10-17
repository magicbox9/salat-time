import { Head, Link } from '@inertiajs/react';
import { ArrowLeft, Eye, Lock, Settings2 } from 'lucide-react';
import { CampaignHero } from '@/components/fundraising/campaign-hero';
import { DonatePanel } from '@/components/fundraising/donate-panel';
import { DonationWall } from '@/components/fundraising/donation-wall';
import { ProgressPanel } from '@/components/fundraising/progress-panel';
import { ShareButtons } from '@/components/fundraising/share-buttons';
import type {
    AvailableMethods,
    CampaignDetail,
    CampaignProgress,
    CampaignUpdateData,
    PayPalConfig,
} from '@/components/fundraising/types';
import { UpdatesTimeline } from '@/components/fundraising/updates-timeline';
import { useLiveProgress } from '@/components/fundraising/use-live-progress';
import { MarkdownContent } from '@/components/markdown-content';
import { Button } from '@/components/ui/button';
import { useT } from '@/lib/i18n';

type Props = {
    campaign: CampaignDetail;
    progress: CampaignProgress;
    updates: CampaignUpdateData[];
    methods: AvailableMethods;
    paypal: PayPalConfig | null;
    presets: number[];
    limits: { min: number; max: number };
    donor: { name: string; email: string } | null;
    canManage: boolean;
    shareUrl: string;
};

const PUBLIC = ['active', 'completed', 'closed'];

/** A campaign's page: story, live progress, the mosque's news, recent gifts and the donate panel. */
export default function CampaignShow({
    campaign,
    progress: initial,
    updates,
    methods,
    paypal,
    presets,
    limits,
    donor,
    canManage,
    shareUrl,
}: Props) {
    const t = useT();
    const isPublic = PUBLIC.includes(campaign.status);
    const { progress, bump } = useLiveProgress(
        campaign.slug,
        initial,
        isPublic && campaign.status === 'active',
    );
    const canGive = methods.paypal || methods.bank;
    const mosque = campaign.mosque;

    return (
        <>
            <Head title={campaign.title}>
                <meta name="description" content={campaign.summary} />
                <meta property="og:title" content={campaign.title} />
                <meta property="og:description" content={campaign.summary} />
                {campaign.cover_url && (
                    <meta property="og:image" content={campaign.cover_url} />
                )}
            </Head>

            <div className="mx-auto max-w-6xl space-y-6">
                <div className="flex flex-wrap items-center justify-between gap-3">
                    <Link
                        href="/campaigns"
                        className="inline-flex items-center gap-1.5 text-sm text-muted-foreground transition-colors hover:text-foreground"
                    >
                        <ArrowLeft
                            className="size-4 rtl:rotate-180"
                            aria-hidden
                        />
                        {t('fundraising.all_campaigns')}
                    </Link>
                    {canManage && mosque && (
                        <Button asChild variant="outline" size="sm">
                            <Link
                                href={`/manage/${mosque.slug}/campaigns/${campaign.slug}`}
                            >
                                <Settings2 className="size-4" aria-hidden />
                                {t('fundraising.manage_campaign')}
                            </Link>
                        </Button>
                    )}
                </div>

                {!isPublic && (
                    <p className="flex items-start gap-2 rounded-2xl border border-amber-500/40 bg-amber-500/10 px-4 py-3 text-sm">
                        <Eye className="mt-0.5 size-4 shrink-0" aria-hidden />
                        {t('fundraising.preview_notice', {
                            state: t(`fundraising.state_${campaign.state}`),
                        })}
                    </p>
                )}

                <div className="grid gap-8 lg:grid-cols-[minmax(0,1fr)_400px] lg:grid-rows-[auto_1fr] xl:gap-12">
                    <div className="lg:col-start-1 lg:row-start-1">
                        <CampaignHero campaign={campaign} />
                    </div>

                    <aside className="space-y-4 lg:sticky lg:top-20 lg:col-start-2 lg:row-span-2 lg:row-start-1 lg:self-start">
                        <ProgressPanel
                            progress={progress}
                            bump={bump}
                            live={isPublic}
                        />
                        {canGive && mosque ? (
                            <DonatePanel
                                slug={campaign.slug}
                                mosqueName={mosque.name}
                                methods={methods}
                                paypal={paypal}
                                presets={presets}
                                limits={limits}
                                donor={donor}
                            />
                        ) : (
                            <p className="flex items-start gap-2.5 rounded-3xl border bg-muted/40 p-5 text-sm text-muted-foreground">
                                <Lock
                                    className="mt-0.5 size-4 shrink-0"
                                    aria-hidden
                                />
                                {t(
                                    progress.state === 'active' ||
                                        progress.state === 'upcoming'
                                        ? 'fundraising.not_taking_donations'
                                        : 'fundraising.campaign_over',
                                )}
                            </p>
                        )}
                        {isPublic && (
                            <ShareButtons
                                url={shareUrl}
                                title={campaign.title}
                            />
                        )}
                    </aside>

                    <div className="space-y-12 lg:col-start-1 lg:row-start-2">
                        <section
                            aria-labelledby="story-title"
                            className="space-y-4"
                        >
                            <h2
                                id="story-title"
                                className="text-xl font-semibold tracking-tight"
                            >
                                {t('fundraising.story_title')}
                            </h2>
                            <MarkdownContent
                                html={campaign.story_html}
                                className="max-w-none text-[1.0625rem]"
                            />
                        </section>

                        {updates.length > 0 && (
                            <section
                                aria-labelledby="updates-title"
                                className="space-y-5"
                            >
                                <h2
                                    id="updates-title"
                                    className="text-xl font-semibold tracking-tight"
                                >
                                    {t('fundraising.updates_title')}
                                    <span
                                        className="ms-2 rounded-full bg-gold/20 px-2 py-0.5 align-middle text-xs font-semibold tabular-nums"
                                        dir="ltr"
                                    >
                                        {updates.length}
                                    </span>
                                </h2>
                                <UpdatesTimeline updates={updates} />
                            </section>
                        )}

                        <DonationWall entries={progress.recent} />

                        <p className="rounded-2xl bg-muted/50 p-4 text-sm text-muted-foreground">
                            {t('fundraising.tax_receipt_note')}
                        </p>
                    </div>
                </div>
            </div>
        </>
    );
}
