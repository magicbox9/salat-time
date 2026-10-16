import { Link } from '@inertiajs/react';
import type { LucideIcon } from 'lucide-react';
import {
    ArrowLeftRight,
    Landmark,
    MonitorPlay,
    Navigation,
    SlidersHorizontal,
} from 'lucide-react';
import { mapsUrl } from '@/components/discover/format';
import { useT } from '@/lib/i18n';
import { cn } from '@/lib/utils';
import type { HubMosque } from './types';

const tile =
    'group flex min-h-20 flex-col items-center justify-center gap-1.5 rounded-2xl border bg-card px-2 py-3 text-center text-xs font-medium shadow-xs transition-colors hover:border-primary/40 hover:bg-accent/60 focus-visible:ring-[3px] focus-visible:ring-ring/50 focus-visible:outline-none sm:text-sm';

function TileIcon({ icon: Icon }: { icon: LucideIcon }) {
    return (
        <span className="flex size-9 items-center justify-center rounded-full bg-primary/10 text-primary transition-colors group-hover:bg-primary group-hover:text-primary-foreground">
            <Icon className="size-4.5" aria-hidden />
        </span>
    );
}

/** Full-screen display, the mosque's site, change mosque, directions, customise. */
export function QuickActions({
    mosque,
    onCustomise,
}: {
    mosque: HubMosque;
    onCustomise: () => void;
}) {
    const t = useT();

    return (
        <nav
            aria-label={t('hub.actions')}
            className="grid grid-cols-3 gap-2 sm:grid-cols-5"
        >
            <Link href="/display" className={tile}>
                <TileIcon icon={MonitorPlay} />
                {t('hub.action_display')}
            </Link>
            <Link
                href={`/mosques/${encodeURIComponent(mosque.slug)}`}
                className={tile}
            >
                <TileIcon icon={Landmark} />
                {t('hub.action_page')}
            </Link>
            <Link href="/explore" className={tile}>
                <TileIcon icon={ArrowLeftRight} />
                {t('hub.action_change')}
            </Link>
            <a
                href={mapsUrl(mosque)}
                target="_blank"
                rel="noopener noreferrer"
                className={tile}
            >
                <TileIcon icon={Navigation} />
                {t('discover.directions')}
            </a>
            <button
                type="button"
                onClick={onCustomise}
                className={cn(tile, 'col-span-2 sm:col-span-1')}
            >
                <TileIcon icon={SlidersHorizontal} />
                {t('hub.action_customise')}
            </button>
        </nav>
    );
}
