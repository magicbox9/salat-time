import { usePage } from '@inertiajs/react';
import { Flame, Sparkles, Star, Trophy } from 'lucide-react';
import { intlLocale, useT } from '@/lib/i18n';
import { cn } from '@/lib/utils';
import { HASANAT_TEXT } from './tracker-utils';

type Props = {
    todayHasanat: number;
    totalHasanat: number;
    currentStreak: number;
    bestStreak: number;
};

/** Today's and total hasanat, current and best streak. */
export function StatTiles({
    todayHasanat,
    totalHasanat,
    currentStreak,
    bestStreak,
}: Props) {
    const t = useT();
    const { locale } = usePage().props;
    const number = new Intl.NumberFormat(intlLocale(locale));
    const tiles = [
        {
            key: 'today',
            label: t('prayers.stat_today'),
            value: number.format(todayHasanat),
            icon: Sparkles,
            gold: true,
        },
        {
            key: 'total',
            label: t('prayers.stat_total'),
            value: number.format(totalHasanat),
            icon: Star,
            gold: true,
        },
        {
            key: 'streak',
            label: t('prayers.stat_streak'),
            value: number.format(currentStreak),
            icon: Flame,
            gold: false,
        },
        {
            key: 'best',
            label: t('prayers.stat_best'),
            value: number.format(bestStreak),
            icon: Trophy,
            gold: false,
        },
    ];

    return (
        <div className="grid grid-cols-2 gap-3 lg:grid-cols-4">
            {tiles.map((tile) => (
                <div
                    key={tile.key}
                    className={cn(
                        'rounded-xl border bg-card p-4 shadow-sm',
                        tile.gold && 'border-gold/40 bg-gold/5',
                    )}
                >
                    <div className="flex items-center justify-between gap-2">
                        <p className="text-xs font-medium text-muted-foreground sm:text-sm">
                            {tile.label}
                        </p>
                        <tile.icon
                            className={cn(
                                'size-4 shrink-0',
                                tile.gold ? 'text-gold' : 'text-primary',
                            )}
                        />
                    </div>
                    <p
                        className={cn(
                            'mt-2 text-2xl font-semibold tracking-tight tabular-nums',
                            tile.gold && HASANAT_TEXT,
                        )}
                    >
                        {tile.value}
                    </p>
                </div>
            ))}
        </div>
    );
}
