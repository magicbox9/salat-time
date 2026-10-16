import { BookOpen, HandHeart, MapPinned, Sparkles } from 'lucide-react';
import type { LucideIcon } from 'lucide-react';

export type SiteNavItem = {
    key: string;
    href: string;
    icon: LucideIcon;
    /** Only for signed-in visitors. */
    auth?: boolean;
};

/** Main navigation. Each feature's pages live under these paths. */
export const SITE_NAV: SiteNavItem[] = [
    { key: 'site.nav_mosques', href: '/', icon: MapPinned },
    { key: 'site.nav_quran', href: '/quran', icon: BookOpen },
    { key: 'site.nav_adhkar', href: '/adhkar', icon: Sparkles },
    { key: 'site.nav_prayers', href: '/prayers', icon: HandHeart, auth: true },
];
