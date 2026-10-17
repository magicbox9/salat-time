import { Link } from '@inertiajs/react';
import { BadgeCheck } from 'lucide-react';
import { SiteLogoMark } from '@/components/site/site-logo';
import { useT } from '@/lib/i18n';
import { cn } from '@/lib/utils';
import { Arabesque } from './arabesque';
import type { SiteShell } from './site-types';

/** The cover picture, or the green-and-gold pattern tinted with the mosque's colour. */
export function SiteCover({
    site,
    className,
}: {
    site: SiteShell;
    className?: string;
}) {
    return (
        <div
            className={cn(
                'relative overflow-hidden rounded-3xl bg-[var(--site-accent)]',
                className,
            )}
        >
            {site.cover_url ? (
                <img
                    src={site.cover_url}
                    alt=""
                    className="h-full w-full object-cover"
                    loading="eager"
                />
            ) : (
                <>
                    <Arabesque />
                    {site.accent && (
                        <div className="absolute inset-0 bg-[var(--site-accent)] mix-blend-color" />
                    )}
                </>
            )}
            <div className="pointer-events-none absolute inset-0 bg-gradient-to-t from-black/65 via-black/15 to-transparent" />
            {/* A thin line of the mosque's colour, as a signature. */}
            <div className="absolute inset-x-0 bottom-0 h-1 bg-[var(--site-accent)]" />
        </div>
    );
}

export function VerifiedBadge({ onDark = false }: { onDark?: boolean }) {
    const t = useT();

    return (
        <span
            className={cn(
                'inline-flex shrink-0 items-center gap-1 rounded-full border px-2 py-0.5 text-xs font-medium',
                onDark
                    ? 'border-gold/60 bg-black/25 text-white backdrop-blur-sm'
                    : 'border-gold/50 bg-gold/10 text-foreground',
            )}
            title={t('mosque.verified_hint')}
        >
            <BadgeCheck className="size-3.5 text-gold" aria-hidden />
            {t('mosque.verified')}
        </span>
    );
}

export function SiteLogo({
    site,
    className,
}: {
    site: SiteShell;
    className?: string;
}) {
    const t = useT();

    return site.logo_url ? (
        <img
            src={site.logo_url}
            alt={t('mosque.logo_alt', { name: site.name })}
            className={cn('rounded-xl bg-card object-cover', className)}
        />
    ) : (
        <SiteLogoMark className={cn('rounded-xl', className)} />
    );
}

/** The slim band at the top of the blog, articles and pages: back to the mosque's home. */
export function CompactSiteBand({ site }: { site: SiteShell }) {
    return (
        <div className="relative">
            <SiteCover site={site} className="h-28 sm:h-32" />
            <Link
                href={`/mosques/${site.slug}`}
                className="absolute inset-x-0 bottom-0 flex items-end gap-3 rounded-b-3xl p-4 text-white outline-none focus-visible:ring-2 focus-visible:ring-white/70 sm:p-5"
            >
                <span className="shrink-0 rounded-2xl bg-white/95 p-0.5 shadow-lg ring-1 ring-black/5">
                    <SiteLogo site={site} className="size-11 sm:size-12" />
                </span>
                <span className="min-w-0 pb-0.5">
                    <span className="flex flex-wrap items-center gap-x-2 gap-y-1">
                        <span className="truncate text-lg font-semibold tracking-tight drop-shadow sm:text-xl">
                            {site.name}
                        </span>
                        {site.verified && <VerifiedBadge onDark />}
                    </span>
                    {site.tagline && (
                        <span className="mt-0.5 line-clamp-1 text-sm text-white/85 drop-shadow">
                            {site.tagline}
                        </span>
                    )}
                </span>
            </Link>
        </div>
    );
}
