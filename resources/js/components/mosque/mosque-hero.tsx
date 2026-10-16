import { BadgeCheck, MapPin } from 'lucide-react';
import { SiteLogoMark } from '@/components/site/site-logo';
import { useT } from '@/lib/i18n';
import { Arabesque } from './arabesque';
import { MosqueActions } from './mosque-actions';
import type { MosqueDetails, MosqueViewer } from './types';

type Props = {
    mosque: MosqueDetails;
    viewer: MosqueViewer;
    shareUrl: string;
};

/** Cover (or a green-and-gold pattern), logo, name, address and the visitor's actions. */
export function MosqueHero({ mosque, viewer, shareUrl }: Props) {
    const t = useT();
    const place = [
        mosque.address,
        [mosque.postcode, mosque.city].filter(Boolean).join(' '),
    ]
        .filter(Boolean)
        .join(', ');

    return (
        <section aria-labelledby="mosque-name">
            <div className="relative h-36 overflow-hidden rounded-2xl bg-primary sm:h-52 lg:h-60">
                {mosque.cover_url ? (
                    <img
                        src={mosque.cover_url}
                        alt=""
                        className="h-full w-full object-cover"
                        loading="eager"
                    />
                ) : (
                    <Arabesque />
                )}
                <div className="pointer-events-none absolute inset-0 bg-gradient-to-t from-black/25 to-transparent" />
            </div>

            <div className="flex flex-col gap-4 px-1 sm:flex-row sm:items-end sm:justify-between sm:px-4">
                <div className="flex min-w-0 items-end gap-4">
                    <div className="-mt-10 shrink-0 rounded-2xl border-4 border-background bg-card shadow-sm sm:-mt-12">
                        {mosque.logo_url ? (
                            <img
                                src={mosque.logo_url}
                                alt={t('mosque.logo_alt', {
                                    name: mosque.name,
                                })}
                                className="size-20 rounded-xl object-cover sm:size-24"
                            />
                        ) : (
                            <SiteLogoMark className="size-20 rounded-xl sm:size-24" />
                        )}
                    </div>
                    <div className="min-w-0 pt-3">
                        <h1
                            id="mosque-name"
                            className="flex flex-wrap items-center gap-x-2 text-2xl font-semibold tracking-tight sm:text-3xl"
                        >
                            <span className="break-words">{mosque.name}</span>
                            {mosque.verified && (
                                <span
                                    className="inline-flex items-center gap-1 rounded-full border border-gold/50 bg-gold/10 px-2 py-0.5 text-xs font-medium text-foreground"
                                    title={t('mosque.verified_hint')}
                                >
                                    <BadgeCheck className="size-3.5 text-gold" />
                                    {t('mosque.verified')}
                                </span>
                            )}
                        </h1>
                        {place && (
                            <p className="mt-1 flex items-start gap-1.5 text-sm text-muted-foreground">
                                <MapPin className="mt-0.5 size-4 shrink-0" />
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
