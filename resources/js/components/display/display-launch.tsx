import { Link } from '@inertiajs/react';
import { MonitorPlay } from 'lucide-react';
import { Button } from '@/components/ui/button';

/**
 * CONTRACT (module "display" replaces this placeholder): opens the mosque's
 * full-screen display at /mosques/{slug}/display; managers also get a link to
 * its settings at /manage/{slug}/display.
 */
export function DisplayLaunchButton({ mosqueSlug, canManage }: { mosqueSlug: string; canManage: boolean }) {
    void canManage;

    return (
        <Button variant="outline" asChild>
            <Link href={`/mosques/${mosqueSlug}/display`}>
                <MonitorPlay className="size-4" />
            </Link>
        </Button>
    );
}
