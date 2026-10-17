import { Link } from '@inertiajs/react';
import { MonitorPlay, Settings2 } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { useT } from '@/lib/i18n';

/**
 * CONTRACT C1: opens the mosque's full-screen display at
 * /mosques/{slug}/display; its managers also get a link to the screen's
 * settings at /manage/{slug}/display.
 */
export function DisplayLaunchButton({
    mosqueSlug,
    canManage,
}: {
    mosqueSlug: string;
    canManage: boolean;
}) {
    const t = useT();

    return (
        <div className="flex flex-wrap items-center gap-2">
            <Button
                variant="outline"
                asChild
                className="group gap-2 border-gold/50 bg-linear-to-b from-gold/10 to-transparent hover:border-gold hover:bg-gold/15 dark:border-gold/40"
            >
                <Link
                    href={`/mosques/${mosqueSlug}/display`}
                    title={t('display.launch_hint')}
                >
                    <MonitorPlay className="size-4 text-gold transition-transform group-hover:scale-110 motion-reduce:transition-none" />
                    {t('display.launch')}
                </Link>
            </Button>
            {canManage && (
                <Button
                    variant="ghost"
                    size="sm"
                    asChild
                    className="gap-1.5 text-muted-foreground hover:text-foreground"
                >
                    <Link href={`/manage/${mosqueSlug}/display`}>
                        <Settings2 className="size-4" />
                        {t('display.launch_settings')}
                    </Link>
                </Button>
            )}
        </div>
    );
}
