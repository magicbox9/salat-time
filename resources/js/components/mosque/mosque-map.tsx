import { Navigation } from 'lucide-react';
import { useEffect, useRef, useState } from 'react';
import { Button } from '@/components/ui/button';
import { useAppearance } from '@/hooks/use-appearance';
import { useT } from '@/lib/i18n';
import { tintDarkStyle } from '@/lib/map-theme';
import type { MosqueDetails } from './types';

const STYLE = {
    light: 'https://tiles.openfreemap.org/styles/positron',
    dark: 'https://tiles.openfreemap.org/styles/dark',
};

/** Google Maps directions to the mosque. */
export function directionsUrl(
    mosque: Pick<MosqueDetails, 'lat' | 'lng'>,
): string {
    return `https://www.google.com/maps/dir/?api=1&destination=${mosque.lat},${mosque.lng}`;
}

/** A small, calm map with the mosque's marker (MapLibre + OpenFreeMap tiles). */
export function MosqueMap({ mosque }: { mosque: MosqueDetails }) {
    const t = useT();
    const { resolvedAppearance } = useAppearance();
    const container = useRef<HTMLDivElement>(null);
    const [failed, setFailed] = useState(false);

    useEffect(() => {
        let map: import('maplibre-gl').Map | null = null;
        let cancelled = false;

        // Loaded on demand: keeps MapLibre out of the first paint and out of SSR.
        Promise.all([
            import('maplibre-gl'),
            import('maplibre-gl/dist/maplibre-gl.css'),
        ])
            .then(([maplibre]) => {
                if (cancelled || !container.current) {
                    return;
                }

                const center: [number, number] = [mosque.lng, mosque.lat];
                map = new maplibre.Map({
                    container: container.current,
                    style: STYLE[resolvedAppearance],
                    center,
                    zoom: 15,
                    interactive: false,
                    attributionControl: { compact: true },
                });
                const marker = document.createElement('div');
                marker.className =
                    'size-9 rounded-full border-[3px] border-white bg-primary shadow-lg ring-4 ring-gold/40';
                marker.setAttribute('aria-hidden', 'true');
                new maplibre.Marker({ element: marker })
                    .setLngLat(center)
                    .addTo(map);
                map.on('error', () => undefined);
                if (resolvedAppearance === 'dark') {
                    const instance = map;
                    instance.on('style.load', () => tintDarkStyle(instance));
                }
            })
            .catch(() => setFailed(true));

        return () => {
            cancelled = true;
            map?.remove();
        };
    }, [mosque.lat, mosque.lng, resolvedAppearance]);

    return (
        <div className="overflow-hidden rounded-2xl border bg-card shadow-xs">
            <div className="relative h-48 bg-muted sm:h-56">
                {!failed && (
                    <div
                        ref={container}
                        className="size-full"
                        role="img"
                        aria-label={t('mosque.map_label', {
                            name: mosque.name,
                        })}
                    />
                )}
            </div>
            <div className="flex items-center justify-between gap-2 px-4 py-3">
                <span className="truncate text-sm text-muted-foreground">
                    {[mosque.postcode, mosque.city].filter(Boolean).join(' ')}
                </span>
                <Button asChild size="sm" variant="outline">
                    <a
                        href={directionsUrl(mosque)}
                        target="_blank"
                        rel="noopener noreferrer"
                    >
                        <Navigation className="size-4" />
                        {t('mosque.directions')}
                    </a>
                </Button>
            </div>
        </div>
    );
}
