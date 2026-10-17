import { Link } from '@inertiajs/react';
import { BadgeCheck, CalendarClock, MapPin, Users } from 'lucide-react';
import { useT } from '@/lib/i18n';
import { cn } from '@/lib/utils';
import { KindBadge, StateBadge } from './badges';
import { CampaignCover } from './campaign-cover';
import { useCount, useMoney } from './format';
import { ProgressBar } from './progress-bar';
import type { CampaignCardData } from './types';

/** "12 days left", "Last day", "Ended"… */
export function useDaysLeft(): (
    campaign: Pick<CampaignCardData, 'state' | 'days_left'>,
) => string | null {
    const t = useT();
    const count = useCount();

    return ({ state, days_left }) => {
        if (state !== 'active') {
            return null;
        }

        if (days_left === null) {
            return t('fundraising.no_end_date');
        }

        return days_left <= 1
            ? t('fundraising.last_day')
            : t('fundraising.days_left', { count: count(days_left) });
    };
}

/** A campaign in a grid: cover, mosque, title, progress and time left. */
export function CampaignCard({
    campaign,
    className,
    showMosque = true,
}: {
    campaign: CampaignCardData;
    className?: string;
    showMosque?: boolean;
}) {
    const t = useT();
    const money = useMoney();
    const count = useCount();
    const daysLeft = useDaysLeft()(campaign);

    return (
        <article
            className={cn(
                'group relative flex flex-col overflow-hidden rounded-2xl border bg-card shadow-xs transition-all duration-300 hover:-translate-y-0.5 hover:border-primary/30 hover:shadow-lg motion-reduce:transition-none motion-reduce:hover:translate-y-0',
                className,
            )}
        >
            <CampaignCover url={campaign.cover_url} className="aspect-[16/10]">
                <div className="absolute inset-x-3 top-3 flex items-start justify-between gap-2">
                    <KindBadge kind={campaign.kind} onImage />
                    {campaign.state !== 'active' && (
                        <StateBadge
                            state={campaign.state}
                            className="bg-background/90 backdrop-blur"
                        />
                    )}
                </div>
                {campaign.distance_m !== null && (
                    <span className="absolute start-3 bottom-3 inline-flex items-center gap-1 rounded-full bg-black/35 px-2 py-0.5 text-xs text-white backdrop-blur-md">
                        <MapPin className="size-3" aria-hidden />
                        <span dir="ltr">
                            {count(
                                Math.max(
                                    1,
                                    Math.round(campaign.distance_m / 1000),
                                ),
                            )}{' '}
                            km
                        </span>
                    </span>
                )}
            </CampaignCover>

            <div className="flex flex-1 flex-col gap-3 p-4 sm:p-5">
                {showMosque && campaign.mosque && (
                    <p className="flex min-w-0 items-center gap-1.5 text-xs font-medium text-muted-foreground">
                        <span className="truncate">{campaign.mosque.name}</span>
                        {campaign.mosque.verified && (
                            <BadgeCheck
                                className="size-3.5 shrink-0 text-gold"
                                aria-label={t('fundraising.verified_mosque')}
                            />
                        )}
                        {campaign.mosque.city && (
                            <span className="truncate before:me-1.5 before:content-['·']">
                                {campaign.mosque.city}
                            </span>
                        )}
                    </p>
                )}

                <h3 className="line-clamp-2 text-lg leading-snug font-semibold tracking-tight">
                    <Link
                        href={`/campaigns/${campaign.slug}`}
                        className="after:absolute after:inset-0 focus-visible:outline-none after:focus-visible:rounded-2xl after:focus-visible:ring-[3px] after:focus-visible:ring-ring/50"
                    >
                        {campaign.title}
                    </Link>
                </h3>
                <p className="line-clamp-2 text-sm text-muted-foreground">
                    {campaign.summary}
                </p>

                <div className="mt-auto space-y-2 pt-2">
                    <ProgressBar percent={campaign.percent} />
                    <div className="flex items-baseline justify-between gap-2 text-sm">
                        <p className="min-w-0 truncate">
                            <span className="font-semibold" dir="ltr">
                                {money(campaign.raised, campaign.currency)}
                            </span>{' '}
                            <span className="text-muted-foreground">
                                {t('fundraising.of_goal', {
                                    goal: money(
                                        campaign.goal,
                                        campaign.currency,
                                    ),
                                })}
                            </span>
                        </p>
                        <span
                            className="shrink-0 font-medium text-primary tabular-nums"
                            dir="ltr"
                        >
                            {Math.floor(campaign.percent)}%
                        </span>
                    </div>
                    <div className="flex items-center justify-between gap-2 text-xs text-muted-foreground">
                        <span className="inline-flex items-center gap-1">
                            <Users className="size-3.5" aria-hidden />
                            {campaign.donors_count === 1
                                ? t('fundraising.donors_count_one')
                                : t('fundraising.donors_count', {
                                      count: count(campaign.donors_count),
                                  })}
                        </span>
                        {daysLeft && (
                            <span className="inline-flex items-center gap-1">
                                <CalendarClock
                                    className="size-3.5"
                                    aria-hidden
                                />
                                {daysLeft}
                            </span>
                        )}
                    </div>
                </div>
            </div>
        </article>
    );
}
