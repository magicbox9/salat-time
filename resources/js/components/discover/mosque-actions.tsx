import { Link } from '@inertiajs/react';
import { ArrowUpRight, Heart, Home, Navigation } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { useT } from '@/lib/i18n';
import { cn } from '@/lib/utils';
import { mapsUrl } from './format';
import type { MosquePin } from './types';

type Props = {
    mosque: MosquePin;
    favorite: boolean;
    primary: boolean;
    busy: boolean;
    onToggleFavorite: () => void;
    onTogglePrimary: () => void;
};

/** Open the mosque's page, save it, make it "my mosque", get directions. */
export function MosqueActions({
    mosque,
    favorite,
    primary,
    busy,
    onToggleFavorite,
    onTogglePrimary,
}: Props) {
    const t = useT();

    return (
        <div className="space-y-2">
            <Button asChild className="w-full">
                <Link href={`/mosques/${encodeURIComponent(mosque.slug)}`}>
                    {t('discover.open_page')}
                    <ArrowUpRight className="rtl:-scale-x-100" />
                </Link>
            </Button>
            <div className="grid grid-cols-3 gap-2">
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
                    disabled={busy}
                    aria-pressed={primary}
                    onClick={onTogglePrimary}
                    className={cn(
                        'h-auto flex-col gap-1 py-2 text-xs',
                        primary && 'border-gold/60',
                    )}
                >
                    <Home className={cn('size-4', primary && 'text-gold')} />
                    {primary
                        ? t('discover.my_mosque')
                        : t('discover.set_my_mosque')}
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
        </div>
    );
}
