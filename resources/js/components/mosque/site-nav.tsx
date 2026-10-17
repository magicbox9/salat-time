import { Link } from '@inertiajs/react';
import {
    BookOpenText,
    Clock,
    FileText,
    HandCoins,
    House,
    Mail,
    Mic,
} from 'lucide-react';
import type { LucideIcon } from 'lucide-react';
import { useEffect, useRef } from 'react';
import { useT } from '@/lib/i18n';
import { cn } from '@/lib/utils';
import type { SiteShell } from './site-types';

/** Which entry of the menu the current page is. */
export type SiteSection = 'home' | 'blog' | 'khutbah' | `page:${string}`;

type Item = {
    key: string;
    href: string;
    label: string;
    icon: LucideIcon;
    /** An anchor on the home page (plain link: the browser scrolls). */
    anchor?: boolean;
    tone?: 'gold';
};

function items(
    site: SiteShell,
    t: (key: string) => string,
    onHome: boolean,
): Item[] {
    const home = `/mosques/${site.slug}`;
    const list: (Item | false)[] = [
        {
            key: 'home',
            href: home,
            label: t('mosquesite.nav_home'),
            icon: House,
        },
        {
            key: 'times',
            href: onHome ? '#prayer-times' : `${home}#prayer-times`,
            label: t('mosquesite.nav_times'),
            icon: Clock,
            anchor: onHome,
        },
        {
            key: 'blog',
            href: `${home}/blog`,
            label: t('mosquesite.nav_blog'),
            icon: BookOpenText,
        },
        site.khutbah && {
            key: 'khutbah',
            href: `${home}/blog?category=khutbah`,
            label: t('mosquesite.nav_khutbahs'),
            icon: Mic,
        },
        ...site.menu.map((page) => ({
            key: `page:${page.slug}`,
            href: `${home}/pages/${page.slug}`,
            label: page.title,
            icon: FileText,
        })),
        site.donate && {
            key: 'donate',
            href: `${home}/campaigns`,
            label: t('mosquesite.nav_donate'),
            icon: HandCoins,
            tone: 'gold',
        },
        {
            key: site.contact_page ? `page:${site.contact_page}` : 'contact',
            href: site.contact_page
                ? `${home}/pages/${site.contact_page}`
                : onHome
                  ? '#contact'
                  : `${home}#contact`,
            label: t('mosquesite.nav_contact'),
            icon: Mail,
            anchor: onHome && !site.contact_page,
        },
    ];

    return list.filter((item): item is Item => item !== false);
}

/** Smooth scrolling to a section of the home page, unless the visitor prefers less motion. */
function scrollToAnchor(
    event: React.MouseEvent<HTMLAnchorElement>,
    hash: string,
): void {
    const target = document.getElementById(hash.slice(1));

    if (!target) {
        return;
    }

    event.preventDefault();
    const reduce = window.matchMedia(
        '(prefers-reduced-motion: reduce)',
    ).matches;
    target.scrollIntoView({
        behavior: reduce ? 'auto' : 'smooth',
        block: 'start',
    });
    window.history.replaceState(window.history.state, '', hash);
}

/** The mosque's menu: sticky under the site header, scrollable pills on phones. */
export function SiteNav({
    site,
    current,
}: {
    site: SiteShell;
    current: SiteSection;
}) {
    const t = useT();
    const scroller = useRef<HTMLDivElement>(null);
    const list = items(site, t, current === 'home');

    // Keeps the current entry in view on narrow screens (only sideways: never moves the page).
    useEffect(() => {
        const bar = scroller.current;
        const active = bar?.querySelector<HTMLElement>('[aria-current="page"]');

        if (!bar || !active || bar.scrollWidth <= bar.clientWidth) {
            return;
        }

        const barBox = bar.getBoundingClientRect();
        const box = active.getBoundingClientRect();
        bar.scrollBy({
            left: box.left + box.width / 2 - (barBox.left + barBox.width / 2),
        });
    }, [current]);

    return (
        <nav
            aria-label={t('mosquesite.menu_label', { name: site.name })}
            className="sticky top-[4.5rem] z-30 rounded-2xl border bg-background/85 shadow-xs backdrop-blur supports-[backdrop-filter]:bg-background/70"
        >
            <div
                ref={scroller}
                className="flex [scrollbar-width:none] gap-1 overflow-x-auto p-1.5 [&::-webkit-scrollbar]:hidden"
            >
                {list.map((item) => {
                    const active = item.key === current;
                    const className = cn(
                        'flex shrink-0 items-center gap-1.5 rounded-xl px-3 py-2 text-sm font-medium whitespace-nowrap transition-colors outline-none focus-visible:ring-2 focus-visible:ring-[var(--site-accent)]/60',
                        active
                            ? 'bg-[var(--site-accent)] text-[var(--site-accent-fg)] shadow-sm'
                            : item.tone === 'gold'
                              ? 'text-foreground hover:bg-gold/15'
                              : 'text-muted-foreground hover:bg-accent hover:text-foreground',
                    );
                    const content = (
                        <>
                            <item.icon
                                className={cn(
                                    'size-4',
                                    item.tone === 'gold' &&
                                        !active &&
                                        'text-gold',
                                )}
                                aria-hidden
                            />
                            {item.label}
                        </>
                    );

                    return item.anchor ? (
                        <a
                            key={item.key}
                            href={item.href}
                            className={className}
                            onClick={(event) =>
                                scrollToAnchor(event, item.href)
                            }
                        >
                            {content}
                        </a>
                    ) : (
                        <Link
                            key={item.key}
                            href={item.href}
                            className={className}
                            aria-current={active ? 'page' : undefined}
                            preserveScroll={false}
                        >
                            {content}
                        </Link>
                    );
                })}
            </div>
        </nav>
    );
}
