import {
    CalendarClock,
    ExternalLink,
    Globe,
    Mail,
    MapPinned,
    Phone,
} from 'lucide-react';
import type { LucideIcon } from 'lucide-react';
import { useT } from '@/lib/i18n';
import { LinkedText } from './linked-text';
import type { MosqueDetails } from './types';

type Item = {
    href: string;
    label: string;
    detail?: string;
    icon: LucideIcon;
    external?: boolean;
};

/** About the mosque: description and every way to reach it. */
export function MosqueAbout({ mosque }: { mosque: MosqueDetails }) {
    const t = useT();
    const items: Item[] = [
        mosque.website && {
            href: mosque.website,
            label: t('mosque.website'),
            detail: mosque.website
                .replace(/^https?:\/\/(www\.)?/i, '')
                .replace(/\/$/, ''),
            icon: Globe,
            external: true,
        },
        mosque.phone && {
            href: `tel:${mosque.phone.replace(/[^0-9+]/g, '')}`,
            label: t('mosque.phone'),
            detail: mosque.phone,
            icon: Phone,
        },
        mosque.email && {
            href: `mailto:${mosque.email}`,
            label: t('mosque.email'),
            detail: mosque.email,
            icon: Mail,
        },
        mosque.mawaqit_url && {
            href: mosque.mawaqit_url,
            label: t('mosque.mawaqit_page'),
            icon: CalendarClock,
            external: true,
        },
        {
            href: mosque.google_maps_url,
            label: t('mosque.open_in_maps'),
            icon: MapPinned,
            external: true,
        },
    ].filter(Boolean) as Item[];

    return (
        <section
            aria-labelledby="about-mosque"
            className="rounded-2xl border bg-card p-5 shadow-xs"
        >
            <h2 id="about-mosque" className="font-semibold">
                {t('mosque.about')}
            </h2>
            {mosque.description ? (
                <LinkedText
                    text={mosque.description}
                    className="mt-2 text-sm text-muted-foreground"
                />
            ) : (
                <p className="mt-2 text-sm text-muted-foreground">
                    {t('mosque.no_description')}
                </p>
            )}
            <ul className="mt-4 space-y-1">
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
                            className="group flex items-center gap-3 rounded-lg px-2 py-2 transition-colors hover:bg-accent/60"
                        >
                            <item.icon className="size-4 shrink-0 text-primary" />
                            <span className="min-w-0 flex-1">
                                <span className="block text-sm font-medium">
                                    {item.label}
                                </span>
                                {item.detail && (
                                    <span
                                        className="block truncate text-xs text-muted-foreground"
                                        dir="ltr"
                                    >
                                        {item.detail}
                                    </span>
                                )}
                            </span>
                            {item.external && (
                                <ExternalLink className="size-3.5 shrink-0 text-muted-foreground opacity-0 transition-opacity group-hover:opacity-100" />
                            )}
                        </a>
                    </li>
                ))}
            </ul>
        </section>
    );
}
