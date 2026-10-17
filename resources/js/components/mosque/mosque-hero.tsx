import { MapPin } from 'lucide-react';
import { MosqueActions } from './mosque-actions';
import { SiteCover, SiteLogo, VerifiedBadge } from './site-band';
import type { SiteMosqueDetails, SiteShell } from './site-types';
import type { MosqueViewer } from './types';

type Props = {
    site: SiteShell;
    mosque: SiteMosqueDetails;
    viewer: MosqueViewer;
    shareUrl: string;
};

/** The home page's band: cover, logo, name, tagline, address and the visitor's actions. */
export function MosqueHero({ site, mosque, viewer, shareUrl }: Props) {
    const place = [
        mosque.address,
        [mosque.postcode, mosque.city].filter(Boolean).join(' '),
    ]
        .filter(Boolean)
        .join(', ');

    return (
        <section aria-labelledby="mosque-name">
            <SiteCover site={site} className="h-36 sm:h-52 lg:h-64" />

            <div className="flex flex-col gap-4 px-1 sm:flex-row sm:items-end sm:justify-between sm:px-4">
                <div className="flex min-w-0 items-end gap-4">
                    <div className="-mt-10 shrink-0 rounded-2xl border-4 border-background bg-card shadow-sm sm:-mt-12">
                        <SiteLogo site={site} className="size-20 sm:size-24" />
                    </div>
                    <div className="min-w-0 pt-3">
                        <h1
                            id="mosque-name"
                            className="flex flex-wrap items-center gap-x-2 gap-y-1 text-2xl font-semibold tracking-tight sm:text-3xl"
                        >
                            <span className="break-words">{mosque.name}</span>
                            {mosque.verified && <VerifiedBadge />}
                        </h1>
                        {mosque.tagline && (
                            <p className="mt-1 text-base text-foreground/80">
                                {mosque.tagline}
                            </p>
                        )}
                        {place && (
                            <p className="mt-1 flex items-start gap-1.5 text-sm text-muted-foreground">
                                <MapPin
                                    className="mt-0.5 size-4 shrink-0"
                                    aria-hidden
                                />
                                <span className="break-words">{place}</span>
                            </p>
                        )}
                        {mosque.association && (
                            <p className="mt-0.5 truncate text-sm text-muted-foreground">
                                {mosque.association}
                            </p>
                        )}
                    </div>
                </div>
                <MosqueActions
                    mosque={mosque}
                    viewer={viewer}
                    shareUrl={shareUrl}
                />
            </div>
        </section>
    );
}
