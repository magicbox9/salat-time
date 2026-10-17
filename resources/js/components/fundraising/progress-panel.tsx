import { CalendarClock, Hourglass, Landmark, Users } from 'lucide-react';
import { useT } from '@/lib/i18n';
import { cn } from '@/lib/utils';
import { AnimatedAmount } from './animated-amount';
import { StateBadge } from './badges';
import { useDaysLeft } from './campaign-card';
import { useCount, useMoney, usePercent } from './format';
import { ProgressBar } from './progress-bar';
import type { CampaignProgress } from './types';

/** The big figures of a campaign: raised (counting up live), goal, donors, time left, pledges. */
export function ProgressPanel({
    progress,
    bump,
    live,
}: {
    progress: CampaignProgress;
    bump: boolean;
    live: boolean;
}) {
    const t = useT();
    const money = useMoney();
    const count = useCount();
    const percent = usePercent();
    const daysLeft = useDaysLeft()(progress);
    const pledgedPercent =
        progress.goal > 0 ? (progress.pledged * 100) / progress.goal : 0;

    return (
        <section
            aria-labelledby="campaign-progress"
            className={cn(
                'relative overflow-hidden rounded-3xl border bg-card p-5 shadow-sm transition-shadow duration-700 sm:p-6',
                bump &&
                    'shadow-[0_0_0_3px_color-mix(in_oklch,var(--gold)_45%,transparent)]',
            )}
        >
            <div
                aria-hidden
                className="pointer-events-none absolute -end-16 -top-16 size-48 rounded-full bg-gold/15 blur-3xl"
            />
            <div className="relative flex items-start justify-between gap-3">
                <h2 id="campaign-progress" className="sr-only">
                    {t('fundraising.progress_title')}
                </h2>
                <div className="min-w-0">
                    <p
                        className={cn(
                            'text-3xl font-semibold tracking-tight tabular-nums transition-colors duration-700 sm:text-4xl',
                            bump && 'text-primary',
                        )}
                    >
                        <AnimatedAmount
                            value={progress.raised}
                            format={(v) => money(v, progress.currency)}
                        />
                    </p>
                    <p className="mt-1 text-sm text-muted-foreground">
                        {t('fundraising.raised_of_goal', {
                            goal: money(progress.goal, progress.currency),
                        })}
                    </p>
                </div>
                {live && progress.state === 'active' ? (
                    <span className="inline-flex shrink-0 items-center gap-1.5 rounded-full bg-emerald-500/10 px-2.5 py-1 text-xs font-medium text-emerald-800 dark:text-emerald-300">
                        <span className="relative flex size-2">
                            <span className="absolute inline-flex size-full animate-ping rounded-full bg-emerald-500 opacity-60 motion-reduce:hidden" />
                            <span className="relative inline-flex size-2 rounded-full bg-emerald-500" />
                        </span>
                        {t('fundraising.live')}
                    </span>
                ) : (
                    <StateBadge state={progress.state} className="shrink-0" />
                )}
            </div>

            <div className="relative mt-5 space-y-2">
                <ProgressBar
                    percent={progress.percent}
                    pledgedPercent={pledgedPercent}
                    size="lg"
                />
                <p
                    className="text-end text-sm font-semibold text-primary tabular-nums"
                    dir="ltr"
                >
                    {percent(progress.percent)}%
                </p>
            </div>

            <dl className="relative mt-3 grid grid-cols-2 gap-3 text-sm">
                <div className="rounded-2xl bg-muted/60 px-3 py-2.5">
                    <dt className="flex items-center gap-1.5 text-xs text-muted-foreground">
                        <Users className="size-3.5" aria-hidden />
                        {t('fundraising.donors')}
                    </dt>
                    <dd className="mt-0.5 text-lg font-semibold tabular-nums">
                        <AnimatedAmount
                            value={progress.donors_count}
                            format={count}
                            duration={700}
                        />
                    </dd>
                </div>
                <div className="rounded-2xl bg-muted/60 px-3 py-2.5">
                    <dt className="flex items-center gap-1.5 text-xs text-muted-foreground">
                        <CalendarClock className="size-3.5" aria-hidden />
                        {t('fundraising.time_left')}
                    </dt>
                    <dd className="mt-0.5 text-lg font-semibold">
                        {daysLeft ?? t(`fundraising.state_${progress.state}`)}
                    </dd>
                </div>
            </dl>

            {progress.pledged > 0 && (
                <p className="relative mt-3 flex items-start gap-2 rounded-2xl border border-dashed border-gold/50 bg-gold/5 px-3 py-2.5 text-sm">
                    <Landmark
                        className="mt-0.5 size-4 shrink-0 text-amber-700 dark:text-gold"
                        aria-hidden
                    />
                    <span>
                        {t('fundraising.pledged_line', {
                            amount: money(progress.pledged, progress.currency),
                        })}
                    </span>
                </p>
            )}

            {progress.state === 'upcoming' && (
                <p className="relative mt-3 flex items-center gap-2 text-sm text-muted-foreground">
                    <Hourglass className="size-4" aria-hidden />
                    {t('fundraising.upcoming_hint')}
                </p>
            )}
        </section>
    );
}
