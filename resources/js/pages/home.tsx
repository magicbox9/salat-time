import { Head, usePage } from '@inertiajs/react';
import { ScanSearch } from 'lucide-react';
import { useEffect, useRef, useState } from 'react';
import { chooseMosque } from '@/components/discover/choose-mosque';
import { GlobeMap } from '@/components/discover/globe/globe-map';
import type { GlobeApi } from '@/components/discover/globe/globe-map';
import { MobileSheet } from '@/components/discover/mobile-sheet';
import { MosquePanel } from '@/components/discover/mosque-panel';
import { NearbyList } from '@/components/discover/nearby-list';
import { SearchCard } from '@/components/discover/search-card';
import { Starfield } from '@/components/discover/starfield';
import type { MosqueCard, MosquePin } from '@/components/discover/types';
import { useDiscover } from '@/components/discover/use-discover';
import { useFavorites } from '@/components/discover/use-favorites';
import { useGeolocation } from '@/components/discover/use-geolocation';
import { SiteHeader } from '@/components/site/site-header';
import { Button } from '@/components/ui/button';
import { useAppearance } from '@/hooks/use-appearance';
import { useFlashToast } from '@/hooks/use-flash-toast';
import { useIsMobile } from '@/hooks/use-mobile';
import { useDocumentLocale } from '@/layouts/site-layout';
import { useT } from '@/lib/i18n';
import { cn } from '@/lib/utils';

type Props = {
    favorites: MosqueCard[];
    primary: MosqueCard | null;
    initialCountry: string;
};

/** Delay before a returning visitor is flown to their own mosque (the globe turns a little first). */
const WELCOME_DELAY_MS = 2200;

/**
 * The globe ("/" before a mosque is chosen, and always "/explore"): a turning
 * 3D globe on a night sky. Choosing a place (or "use my location") flies the
 * camera down and lists the mosques nearby; choosing a mosque shows its
 * published times for today, and "Make it my mosque" makes "/" open on them.
 */
export default function Home({
    favorites: savedMosques,
    primary,
    initialCountry,
}: Props) {
    useDocumentLocale();
    useFlashToast();
    const t = useT();
    const { dir } = usePage().props;
    const { resolvedAppearance } = useAppearance();
    const isMobile = useIsMobile();
    const globe = useRef<GlobeApi>(null);
    const acted = useRef(false);
    const discover = useDiscover(globe, dir);
    const favorites = useFavorites(savedMosques);
    const [country, setCountry] = useState(initialCountry);
    const [highlight, setHighlight] = useState<number | null>(null);
    const [welcomeId, setWelcomeId] = useState<number | null>(null);
    const [mapFailed, setMapFailed] = useState(false);
    const { locate, locating } = useGeolocation((point) => {
        acted.current = true;
        void discover.searchAround({
            ...point,
            label: t('discover.your_location'),
            kind: 'me',
        });
    });

    // Welcome back: after a short turn of the globe, fly to the visitor's own mosque.
    const welcome = useRef(() => {
        if (primary && !acted.current) {
            setWelcomeId(primary.id);
            discover.openMosque(primary);
        }
    });
    useEffect(() => {
        if (!primary) {
            return;
        }

        const timer = window.setTimeout(
            () => welcome.current(),
            WELCOME_DELAY_MS,
        );

        return () => window.clearTimeout(timer);
    }, [primary]);

    // "Make it my mosque" (guests too): then "/" opens on its prayer times.
    const [choosing, setChoosing] = useState(false);
    const choose = (pin: MosquePin) => chooseMosque(pin.slug, t, setChoosing);
    const isPrimary = (id: number) =>
        id === primary?.id || favorites.isPrimary(id);

    const findPin = (id: number): MosquePin | null =>
        [
            ...(discover.nearby?.mosques ?? []),
            ...favorites.favorites,
            ...discover.dots,
        ].find((pin) => pin.id === id) ?? null;
    const open = (pin: MosquePin) => {
        acted.current = true;
        discover.openMosque(pin);
    };

    const selected = discover.selected;
    const docked = discover.origin !== null || selected !== null;
    const listTitle = discover.loading
        ? t('discover.searching_near', { place: discover.origin?.label ?? '' })
        : t('discover.found_count', {
              count: discover.nearby?.mosques.length ?? 0,
              radius: discover.nearby?.radiusKm ?? '',
          });

    const list = discover.origin && (
        <NearbyList
            origin={discover.origin}
            mosques={discover.nearby?.mosques ?? null}
            radiusKm={discover.nearby?.radiusKm ?? null}
            loading={discover.loading}
            failed={discover.failed}
            selectedId={selected?.id ?? null}
            isFavorite={favorites.isFavorite}
            isPrimary={isPrimary}
            onOpen={open}
            onHover={setHighlight}
            onRetry={() => void discover.retry()}
            showCount={!isMobile}
            className="min-h-0 flex-1"
        />
    );

    const panel = selected && (
        <MosquePanel
            key={selected.id}
            mosque={selected}
            welcome={welcomeId === selected.id}
            favorite={favorites.isFavorite(selected.id)}
            chosen={selected.id === primary?.id}
            busy={favorites.pending === selected.id}
            choosing={choosing}
            onToggleFavorite={() => void favorites.toggleFavorite(selected)}
            onChoose={() => choose(selected)}
            onClose={discover.close}
            className={
                isMobile
                    ? 'max-h-[60svh] rounded-b-none border-b-0'
                    : 'max-h-[calc(100svh-5.5rem)]'
            }
        />
    );

    const searchHere = () => {
        if (discover.view) {
            const { center, zoom } = discover.view;
            void discover.searchAround(
                { ...center, label: t('discover.this_area'), kind: 'place' },
                { zoom },
            );
        }
    };

    return (
        <div className="relative h-svh w-full overflow-hidden bg-[oklch(0.12_0.03_220)] text-foreground">
            <Head title={t('discover.page_title')} />
            <Starfield />
            {mapFailed ? (
                <p className="absolute inset-x-4 bottom-8 z-10 text-center text-sm text-white/70">
                    {t('discover.map_unavailable')}
                </p>
            ) : (
                <GlobeMap
                    ref={globe}
                    theme={resolvedAppearance}
                    dir={dir}
                    label={t('discover.map_label')}
                    nearby={discover.nearby?.mosques ?? []}
                    dots={discover.dots}
                    favorites={favorites.favorites}
                    origin={discover.origin}
                    selected={selected}
                    highlightId={highlight}
                    nameOf={(id) => findPin(id)?.name ?? null}
                    onSelect={(id) => {
                        const pin = findPin(id);

                        if (pin) {
                            open(pin);
                        }
                    }}
                    onViewChange={discover.onViewChange}
                    onInteract={() => {
                        // Exploring the globe: do not pull the camera away to "my mosque".
                        acted.current = true;
                    }}
                    onFail={() => setMapFailed(true)}
                />
            )}
            <SiteHeader overlay />

            <div
                className={cn(
                    'pointer-events-none absolute z-30',
                    docked
                        ? 'inset-x-3 top-[4.25rem] flex flex-col gap-3 md:inset-x-auto md:start-4 md:bottom-4 md:w-[400px]'
                        : 'inset-0 flex items-end justify-center px-4 pt-16 pb-[max(2.5rem,env(safe-area-inset-bottom))] sm:pb-[7svh]',
                )}
            >
                <SearchCard
                    variant={docked ? 'docked' : 'hero'}
                    country={country}
                    onCountryChange={setCountry}
                    onPlace={(place) => {
                        acted.current = true;
                        void discover.searchAround({
                            lat: place.lat,
                            lng: place.lng,
                            label: place.label,
                            kind: place.kind,
                        });
                    }}
                    onMosque={(mosque) => {
                        acted.current = true;
                        void discover.searchAround(
                            {
                                lat: mosque.lat,
                                lng: mosque.lng,
                                label: mosque.name,
                                kind: 'mosque',
                            },
                            { select: mosque },
                        );
                    }}
                    onLocate={locate}
                    locating={locating}
                    className="pointer-events-auto"
                />
                {!isMobile && list && (
                    <div className="pointer-events-auto flex min-h-0 flex-1 flex-col rounded-2xl border bg-background/92 p-3 shadow-xl backdrop-blur-xl">
                        {list}
                    </div>
                )}
            </div>

            {!isMobile && panel && (
                <div className="absolute end-4 top-[4.25rem] z-30 w-[380px]">
                    {panel}
                </div>
            )}

            {isMobile && docked && (
                <div className="absolute inset-x-0 bottom-0 z-30">
                    {panel ||
                        (list && (
                            <MobileSheet title={listTitle}>{list}</MobileSheet>
                        ))}
                </div>
            )}

            {discover.canSearchHere && (
                <Button
                    size="sm"
                    onClick={searchHere}
                    className={cn(
                        'absolute left-1/2 z-30 -translate-x-1/2 rounded-full shadow-lg',
                        isMobile ? 'top-[8.5rem]' : 'top-[4.75rem]',
                    )}
                >
                    <ScanSearch />
                    {t('discover.search_here')}
                </Button>
            )}
        </div>
    );
}
