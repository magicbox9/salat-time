import { Link } from '@inertiajs/react';
import { Building2, Globe2, HeartHandshake } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { useT } from '@/lib/i18n';
import type { DayTimes, MosqueSummary } from '@/types/mosque';

type Props = {
    mosque: MosqueSummary | null;
    times: DayTimes | null;
    timezone: string;
};

/** Whose times the tracker follows — or an invitation to choose one's mosque. */
export function MosqueBanner({ mosque, times, timezone }: Props) {
    const t = useT();

    if (!mosque) {
        return (
            <div className="flex flex-col gap-4 rounded-xl border border-dashed border-primary/40 bg-primary/5 p-4 sm:flex-row sm:items-center sm:p-5">
                <span className="flex size-11 shrink-0 items-center justify-center rounded-full bg-primary/12 text-primary">
                    <Globe2 className="size-5" />
                </span>
                <div className="flex-1 space-y-1">
                    <p className="font-medium">
                        {t('prayers.no_mosque_title')}
                    </p>
                    <p className="text-sm text-muted-foreground">
                        {t('prayers.no_mosque_text')}
                    </p>
                    <p className="text-xs text-muted-foreground">
                        {t('prayers.timezone_note')}{' '}
                        <span dir="ltr">{timezone}</span>
                    </p>
                </div>
                <Button asChild className="shrink-0">
                    <Link href="/">{t('prayers.no_mosque_action')}</Link>
                </Button>
            </div>
        );
    }

    return (
        <div className="flex flex-wrap items-center gap-x-3 gap-y-1 text-sm text-muted-foreground">
            <Building2 className="size-4 shrink-0 text-primary" />
            <span>{t('prayers.times_from')}</span>
            <Link
                href={`/mosques/${mosque.slug}`}
                className="font-medium text-foreground underline-offset-4 hover:underline"
            >
                {mosque.name}
            </Link>
            {mosque.city && <span>· {mosque.city}</span>}
            {!times && (
                <span className="flex items-center gap-1.5 text-amber-700 dark:text-amber-300">
                    <HeartHandshake className="size-4" />
                    {t('site.no_times')}
                </span>
            )}
        </div>
    );
}
