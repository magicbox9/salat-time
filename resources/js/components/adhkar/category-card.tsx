import { Link } from '@inertiajs/react';
import { Check } from 'lucide-react';
import { countLabel } from '@/components/quran/types';
import { useT } from '@/lib/i18n';
import { cn } from '@/lib/utils';
import { categoryIcon } from './types';
import type { AdhkarCategory } from './types';

type Props = {
    category: AdhkarCategory;
    /** Adhkar completed today on this device. */
    done: number;
    /** Morning and evening get the large card. */
    featured?: boolean;
    badge?: string | null;
    subtitle?: string | null;
};

export function CategoryCard({
    category,
    done,
    featured = false,
    badge = null,
    subtitle = null,
}: Props) {
    const t = useT();
    const Icon = categoryIcon(category.key);
    const complete = done >= category.count;
    const ratio = Math.min(1, done / category.count);

    return (
        <Link
            href={`/adhkar/${category.key}`}
            className={cn(
                'group relative flex flex-col gap-4 overflow-hidden rounded-2xl border bg-card p-5 transition-all hover:-translate-y-0.5 hover:border-primary/40 hover:shadow-md focus-visible:ring-[3px] focus-visible:ring-ring/50 focus-visible:outline-none',
                featured && 'p-6 sm:p-7',
                badge && 'border-gold/60 ring-1 ring-gold/30',
            )}
        >
            {featured && (
                <div
                    aria-hidden
                    className={cn(
                        'pointer-events-none absolute inset-0 opacity-60',
                        category.key === 'morning'
                            ? 'bg-[radial-gradient(circle_at_top_right,color-mix(in_oklab,var(--gold)_35%,transparent),transparent_60%)]'
                            : 'bg-[radial-gradient(circle_at_top_right,color-mix(in_oklab,var(--primary)_30%,transparent),transparent_60%)]',
                    )}
                />
            )}
            <div className="relative flex items-start justify-between gap-3">
                <span
                    className={cn(
                        'grid shrink-0 place-items-center rounded-xl bg-primary/10 text-primary transition-colors group-hover:bg-primary/15',
                        featured ? 'size-14' : 'size-11',
                    )}
                >
                    <Icon className={featured ? 'size-7' : 'size-5'} />
                </span>
                {badge && (
                    <span className="rounded-full bg-gold px-2.5 py-1 text-xs font-semibold text-black/80">
                        {badge}
                    </span>
                )}
                {!badge && complete && (
                    <span className="grid size-7 place-items-center rounded-full bg-gold/20">
                        <Check className="size-4 text-gold" aria-hidden />
                        <span className="sr-only">{t('adhkar.done')}</span>
                    </span>
                )}
            </div>
            <div className="relative min-w-0">
                <h2
                    className={cn(
                        'font-semibold',
                        featured ? 'text-xl' : 'text-base',
                    )}
                >
                    {t(`adhkar.cat_${category.key}`)}
                </h2>
                {subtitle && (
                    <p className="mt-0.5 text-sm text-muted-foreground">
                        {subtitle}
                    </p>
                )}
                <p
                    dir="rtl"
                    lang="ar"
                    className={cn(
                        'font-adhkar mt-2 text-start text-muted-foreground',
                        featured ? 'text-2xl' : 'text-lg',
                    )}
                >
                    {category.name_ar}
                </p>
            </div>
            <div className="relative mt-auto space-y-2">
                <div className="flex items-center justify-between text-xs text-muted-foreground">
                    <span>{countLabel(t, 'adhkar.items', category.count)}</span>
                    {done > 0 && (
                        <span className="tabular-nums" dir="ltr">
                            {Math.min(done, category.count)}/{category.count}
                        </span>
                    )}
                </div>
                <div
                    className="h-1.5 overflow-hidden rounded-full bg-muted"
                    aria-hidden
                >
                    <div
                        className={cn(
                            'h-full rounded-full transition-all',
                            complete ? 'bg-gold' : 'bg-primary',
                        )}
                        style={{ width: `${ratio * 100}%` }}
                    />
                </div>
            </div>
        </Link>
    );
}
