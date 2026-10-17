import { MonitorPlay } from 'lucide-react';
import { DisplayLaunchButton } from '@/components/display/display-launch';
import { useT } from '@/lib/i18n';

/** The mosque's full-screen display (a TV in the prayer hall, a screen at home). */
export function DisplayCard({
    slug,
    canManage,
}: {
    slug: string;
    canManage: boolean;
}) {
    const t = useT();

    return (
        <section
            aria-labelledby="mosque-display"
            className="relative overflow-hidden rounded-2xl border bg-gradient-to-br from-[var(--site-accent)]/10 via-card to-card p-5 shadow-xs"
        >
            <MonitorPlay
                aria-hidden
                className="absolute -end-4 -top-4 size-20 text-[var(--site-accent)]/10"
            />
            <h2 id="mosque-display" className="font-semibold">
                {t('mosquesite.display_title')}
            </h2>
            <p className="mt-1 text-sm text-muted-foreground">
                {t('mosquesite.display_body')}
            </p>
            <div className="mt-4 flex flex-wrap gap-2">
                <DisplayLaunchButton mosqueSlug={slug} canManage={canManage} />
            </div>
        </section>
    );
}
