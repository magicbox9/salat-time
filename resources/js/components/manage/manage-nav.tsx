import { Link } from '@inertiajs/react';
import {
    FileText,
    Files,
    HandCoins,
    Landmark,
    LayoutDashboard,
    MessagesSquare,
    MonitorPlay,
    Store,
    Tags,
} from 'lucide-react';
import type { LucideIcon } from 'lucide-react';
import { useCurrentUrl } from '@/hooks/use-current-url';
import { useT } from '@/lib/i18n';
import { cn } from '@/lib/utils';

type Section = {
    href: string;
    label: string;
    icon: LucideIcon;
    exact?: boolean;
};

/** The sections of a mosque's management, grouped. */
export function manageSections(
    slug: string,
    t: (key: string) => string,
): { title: string; items: Section[] }[] {
    const base = `/manage/${slug}`;

    return [
        {
            title: t('manage.group_site'),
            items: [
                {
                    href: base,
                    label: t('manage.nav_overview'),
                    icon: LayoutDashboard,
                    exact: true,
                },
                {
                    href: `${base}/details`,
                    label: t('manage.nav_details'),
                    icon: Store,
                },
                {
                    href: `${base}/posts`,
                    label: t('manage.nav_posts'),
                    icon: FileText,
                },
                {
                    href: `${base}/categories`,
                    label: t('manage.nav_categories'),
                    icon: Tags,
                },
                {
                    href: `${base}/pages`,
                    label: t('manage.nav_pages'),
                    icon: Files,
                },
            ],
        },
        {
            title: t('manage.group_screens_giving'),
            items: [
                {
                    href: `${base}/display`,
                    label: t('manage.nav_display'),
                    icon: MonitorPlay,
                },
                {
                    href: `${base}/campaigns`,
                    label: t('manage.nav_campaigns'),
                    icon: HandCoins,
                },
                {
                    href: `${base}/payouts`,
                    label: t('manage.nav_payouts'),
                    icon: Landmark,
                },
            ],
        },
        {
            title: t('manage.group_community'),
            items: [
                {
                    href: `${base}/comments`,
                    label: t('manage.nav_comments'),
                    icon: MessagesSquare,
                },
            ],
        },
    ];
}

function useActive() {
    const { currentUrl } = useCurrentUrl();
    const path = currentUrl.split('?')[0].replace(/\/$/, '');

    return (section: Section) =>
        section.exact
            ? path === section.href
            : path === section.href || path.startsWith(`${section.href}/`);
}

/** Sidebar on large screens: grouped, with the current section highlighted. */
export function ManageSidebarNav({ slug }: { slug: string }) {
    const t = useT();
    const isActive = useActive();

    return (
        <nav aria-label={t('manage.sections')} className="space-y-5">
            {manageSections(slug, t).map((group) => (
                <div key={group.title}>
                    <p className="px-3 pb-1.5 text-[11px] font-semibold tracking-wider text-muted-foreground uppercase">
                        {group.title}
                    </p>
                    <ul className="space-y-0.5">
                        {group.items.map((item) => {
                            const active = isActive(item);

                            return (
                                <li key={item.href}>
                                    <Link
                                        href={item.href}
                                        aria-current={
                                            active ? 'page' : undefined
                                        }
                                        className={cn(
                                            'flex items-center gap-2.5 rounded-lg px-3 py-2 text-sm font-medium transition-colors outline-none focus-visible:ring-2 focus-visible:ring-ring/50',
                                            active
                                                ? 'bg-primary/10 text-foreground'
                                                : 'text-muted-foreground hover:bg-accent hover:text-foreground',
                                        )}
                                    >
                                        <item.icon
                                            className={cn(
                                                'size-4',
                                                active && 'text-primary',
                                            )}
                                            aria-hidden
                                        />
                                        {item.label}
                                    </Link>
                                </li>
                            );
                        })}
                    </ul>
                </div>
            ))}
        </nav>
    );
}

/** The same sections as scrollable pills (phones, tablets, and pages without the sidebar). */
export function ManagePillNav({
    slug,
    className,
}: {
    slug: string;
    className?: string;
}) {
    const t = useT();
    const isActive = useActive();
    const items = manageSections(slug, t).flatMap((group) => group.items);

    return (
        <nav
            aria-label={t('manage.sections')}
            className={cn(
                '-mx-4 flex [scrollbar-width:none] gap-1 overflow-x-auto px-4 pb-1',
                className,
            )}
        >
            {items.map((item) => {
                const active = isActive(item);

                return (
                    <Link
                        key={item.href}
                        href={item.href}
                        aria-current={active ? 'page' : undefined}
                        className={cn(
                            'flex shrink-0 items-center gap-1.5 rounded-full border px-3 py-1.5 text-sm font-medium transition-colors',
                            active
                                ? 'border-transparent bg-primary text-primary-foreground'
                                : 'bg-card text-muted-foreground hover:text-foreground',
                        )}
                    >
                        <item.icon className="size-3.5" aria-hidden />
                        {item.label}
                    </Link>
                );
            })}
        </nav>
    );
}
