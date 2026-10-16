import { Link } from '@inertiajs/react';
import { ArrowUpRight, Clock, Heart, Home, Navigation } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { useT } from '@/lib/i18n';
import { cn } from '@/lib/utils';
import { mapsUrl } from './format';
import type { MosquePin } from './types';

type Props = {
    mosque: MosquePin;
    favorite: boolean;
    /** Already the visitor's own mosque. */
    chosen: boolean;
    busy: boolean;
    choosing: boolean;
    onToggleFavorite: () => void;
    onChoose: () => void;
};

/**
 * The main action, for everyone (guests too): "Make it my mosque", which
 * opens its prayer times on "/". Then: its page, save it, directions.
 */
export function MosqueActions({
    mosque,
    favorite,
    chosen,
    busy,
    choosing,
    onToggleFavorite,
    onChoose,
}: Props) {
    const t = useT();

    return (
        <div className="space-y-2">
            {chosen ? (
                <Button asChild className="w-full">
                    <Link href="/">
                        <Clock />
                        {t('discover.open_my_times')}
                    </Link>
                </Button>
            ) : (
                <Button
                    className="w-full"
                    disabled={choosing}
                    onClick={onChoose}
                >
                    <Home />
                    {t('discover.make_my_mosque')}
                </Button>
            )}
            <div className="grid grid-cols-3 gap-2">
                <Button
                    variant="outline"
                    size="sm"
                    asChild
                    className="h-auto flex-col gap-1 py-2 text-xs whitespace-normal"
                >
                    <Link href={`/mosques/${encodeURIComponent(mosque.slug)}`}>
                        <ArrowUpRight className="size-4 rtl:-scale-x-100" />
                        {t('discover.mosque_page')}
                    </Link>
                </Button>
                <Button
                    variant="outline"
                    size="sm"
                    disabled={busy}
                    aria-pressed={favorite}
                    onClick={onToggleFavorite}
                    className={cn(
                        'h-auto flex-col gap-1 py-2 text-xs',
                        favorite && 'border-gold/60',
                    )}
                >
                    <Heart
                        className={cn(
                            'size-4',
                            favorite && 'fill-gold text-gold',
                        )}
                    />
                    {favorite ? t('discover.saved') : t('discover.save')}
                </Button>
                <Button
                    variant="outline"
                    size="sm"
                    asChild
                    className="h-auto flex-col gap-1 py-2 text-xs"
                >
                    <a
                        href={mapsUrl(mosque)}
                        target="_blank"
                        rel="noopener noreferrer"
                    >
                        <Navigation className="size-4" />
                        {t('discover.directions')}
                    </a>
                </Button>
            </div>
            {chosen && (
                <p className="flex items-center justify-center gap-1.5 pt-1 text-xs text-gold">
                    <Home className="size-3.5" aria-hidden />
                    {t('discover.is_my_mosque')}
                </p>
            )}
        </div>
    );
}
