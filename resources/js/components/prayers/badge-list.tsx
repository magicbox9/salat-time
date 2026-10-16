import { usePage } from '@inertiajs/react';
import { Award, Clock, Flame, Sparkles, Sunrise, Users } from 'lucide-react';
import type { LucideIcon } from 'lucide-react';
import { intlLocale, useT } from '@/lib/i18n';
import { cn } from '@/lib/utils';
import type { TrackerBadge } from './types';

const ICONS: Record<string, LucideIcon> = {
    first_prayer: Sparkles,
    on_time_100: Clock,
    fajr_mosque_10: Sunrise,
    congregation_40: Users,
    streak_7: Flame,
    streak_30: Award,
};

/** Gentle milestones, earned ones first. */
export function BadgeList({ badges }: { badges: TrackerBadge[] }) {
    const t = useT();
    const { locale } = usePage().props;
    const number = new Intl.NumberFormat(intlLocale(locale));
    const sorted = [...badges].sort(
        (a, b) => Number(b.earned) - Number(a.earned),
    );

    return (
        <section
            className="rounded-xl border bg-card p-4 shadow-sm sm:p-5"
            aria-labelledby="badges-heading"
        >
            <h2 id="badges-heading" className="mb-3 font-semibold">
                {t('prayers.badges_title')}
            </h2>
            <ul className="space-y-3">
                {sorted.map((badge) => {
                    const Icon = ICONS[badge.key] ?? Award;
                    const percent =
                        badge.target > 0
                            ? Math.round((badge.progress / badge.target) * 100)
                            : 0;

                    return (
                        <li key={badge.key} className="flex items-center gap-3">
                            <span
                                className={cn(
                                    'flex size-10 shrink-0 items-center justify-center rounded-full border',
                                    badge.earned
                                        ? 'border-gold/60 bg-gold/15 text-amber-700 dark:text-gold'
                                        : 'border-dashed text-muted-foreground',
                                )}
                            >
                                <Icon className="size-4.5" />
                            </span>
                            <div className="min-w-0 flex-1">
                                <div className="flex items-baseline justify-between gap-2">
                                    <p
                                        className={cn(
                                            'truncate text-sm font-medium',
                                            !badge.earned &&
                                                'text-muted-foreground',
                                        )}
                                    >
                                        {t(`prayers.badge_${badge.key}`)}
                                    </p>
                                    <span
                                        className="shrink-0 text-xs text-muted-foreground tabular-nums"
                                        dir="ltr"
                                    >
                                        {number.format(badge.progress)}/
                                        {number.format(badge.target)}
                                    </span>
                                </div>
                                <div
                                    className="mt-1.5 h-1.5 overflow-hidden rounded-full bg-muted"
                                    role="progressbar"
                                    aria-valuemin={0}
                                    aria-valuemax={badge.target}
                                    aria-valuenow={badge.progress}
                                    aria-label={t(`prayers.badge_${badge.key}`)}
                                >
                                    <div
                                        className={cn(
                                            'h-full rounded-full',
                                            badge.earned
                                                ? 'bg-gold'
                                                : 'bg-primary/60',
                                        )}
                                        style={{ width: `${percent}%` }}
                                    />
                                </div>
                            </div>
                        </li>
                    );
                })}
            </ul>
        </section>
    );
}
