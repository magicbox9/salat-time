import {
    Facebook,
    Instagram,
    MessageCircle,
    Music2,
    Send,
    Youtube,
} from 'lucide-react';
import { useT } from '@/lib/i18n';
import { cn } from '@/lib/utils';
import type { SocialLink, SocialNetwork } from './site-types';

/** The X mark (no brand icon in our icon set). */
function XMark({ className }: { className?: string }) {
    return (
        <svg
            viewBox="0 0 24 24"
            aria-hidden
            className={className}
            fill="currentColor"
        >
            <path d="M17.75 3h3.07l-6.7 7.66L22 21h-6.17l-4.83-6.32L5.47 21H2.4l7.17-8.2L2 3h6.33l4.37 5.77L17.75 3Zm-1.08 16.2h1.7L7.4 4.7H5.57l11.1 14.5Z" />
        </svg>
    );
}

const ICONS: Record<
    SocialNetwork,
    React.ComponentType<{ className?: string }>
> = {
    facebook: Facebook,
    instagram: Instagram,
    youtube: Youtube,
    x: XMark,
    tiktok: Music2,
    whatsapp: MessageCircle,
    telegram: Send,
};

/** Round buttons to the mosque's social accounts (addresses checked by the server). */
export function SocialLinks({
    links,
    className,
}: {
    links: SocialLink[];
    className?: string;
}) {
    const t = useT();

    if (links.length === 0) {
        return null;
    }

    return (
        <ul
            className={cn('flex flex-wrap gap-2', className)}
            aria-label={t('mosquesite.social_title')}
        >
            {links.map((link) => {
                const Icon = ICONS[link.network];
                const label = t(`mosquesite.social_${link.network}`);

                return (
                    <li key={link.network}>
                        <a
                            href={link.url}
                            target="_blank"
                            rel="noopener noreferrer nofollow"
                            aria-label={label}
                            title={label}
                            className="flex size-10 items-center justify-center rounded-full border bg-background text-muted-foreground transition-colors outline-none hover:border-[var(--site-accent)]/50 hover:bg-[var(--site-accent)] hover:text-[var(--site-accent-fg)] focus-visible:ring-2 focus-visible:ring-[var(--site-accent)]/50"
                        >
                            <Icon className="size-4" />
                        </a>
                    </li>
                );
            })}
        </ul>
    );
}
