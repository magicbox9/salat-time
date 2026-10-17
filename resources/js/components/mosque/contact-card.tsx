import {
    CalendarClock,
    ExternalLink,
    Globe,
    Mail,
    MapPin,
    MapPinned,
    Phone,
} from 'lucide-react';
import type { LucideIcon } from 'lucide-react';
import { useT } from '@/lib/i18n';
import type { SiteMosqueDetails } from './site-types';
import { SocialLinks } from './social-links';

type Item = {
    href: string;
    label: string;
    detail?: string;
    icon: LucideIcon;
    external?: boolean;
    ltr?: boolean;
};

/** Every way to reach the mosque: address, phone, email, website, social accounts. */
export function ContactCard({ mosque }: { mosque: SiteMosqueDetails }) {
    const t = useT();
    const address = [
        mosque.address,
        [mosque.postcode, mosque.city].filter(Boolean).join(' '),
    ]
        .filter(Boolean)
        .join(', ');
    const items = [
        address && {
            href: mosque.google_maps_url,
            label: t('mosquesite.address'),
            detail: address,
            icon: MapPin,
            external: true,
        },
        mosque.phone && {
            href: `tel:${mosque.phone.replace(/[^0-9+]/g, '')}`,
            label: t('mosque.phone'),
            detail: mosque.phone,
            icon: Phone,
            ltr: true,
        },
        mosque.email && {
            href: `mailto:${mosque.email}`,
            label: t('mosque.email'),
            detail: mosque.email,
            icon: Mail,
            ltr: true,
        },
        mosque.website && {
            href: mosque.website,
            label: t('mosque.website'),
            detail: mosque.website
                .replace(/^https?:\/\/(www\.)?/i, '')
                .replace(/\/$/, ''),
            icon: Globe,
            external: true,
            ltr: true,
        },
        mosque.mawaqit_url && {
            href: mosque.mawaqit_url,
            label: t('mosque.mawaqit_page'),
            icon: CalendarClock,
            external: true,
        },
        !address && {
            href: mosque.google_maps_url,
            label: t('mosque.open_in_maps'),
            icon: MapPinned,
            external: true,
        },
    ].filter(Boolean) as Item[];

    return (
        <section
            id="contact"
            aria-labelledby="mosque-contact"
            className="scroll-mt-36 rounded-2xl border bg-card p-5 shadow-xs"
        >
            <h2 id="mosque-contact" className="font-semibold">
                {t('mosquesite.contact_title')}
            </h2>
            <ul className="mt-3 space-y-1">
                {items.map((item) => (
                    <li key={item.label}>
                        <a
                            href={item.href}
                            {...(item.external
                                ? {
                                      target: '_blank',
                                      rel: 'noopener noreferrer',
                                  }
                                : {})}
                            className="group flex items-center gap-3 rounded-lg px-2 py-2 transition-colors outline-none hover:bg-accent/60 focus-visible:ring-2 focus-visible:ring-[var(--site-accent)]/50"
                        >
                            <item.icon
                                className="size-4 shrink-0 text-[var(--site-accent-ink)]"
                                aria-hidden
                            />
                            <span className="min-w-0 flex-1">
                                <span className="block text-sm font-medium">
                                    {item.label}
                                </span>
                                {item.detail && (
                                    <span
                                        className="block truncate text-xs text-muted-foreground"
                                        dir={item.ltr ? 'ltr' : undefined}
                                    >
                                        {item.detail}
                                    </span>
                                )}
                            </span>
                            {item.external && (
                                <ExternalLink
                                    className="size-3.5 shrink-0 text-muted-foreground opacity-0 transition-opacity group-hover:opacity-100 group-focus-visible:opacity-100"
                                    aria-hidden
                                />
                            )}
                        </a>
                    </li>
                ))}
            </ul>
            {mosque.social_links.length > 0 && (
                <div className="mt-4 border-t pt-4">
                    <p className="mb-2 text-xs font-medium text-muted-foreground">
                        {t('mosquesite.social_title')}
                    </p>
                    <SocialLinks links={mosque.social_links} />
                </div>
            )}
        </section>
    );
}
