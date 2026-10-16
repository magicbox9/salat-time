import { Link } from '@inertiajs/react';
import {
    ArrowLeft,
    Building2,
    Inbox,
    LayoutDashboard,
    ShieldCheck,
    Users,
} from 'lucide-react';
import type { ReactNode } from 'react';
import { useCurrentUrl } from '@/hooks/use-current-url';
import { useT } from '@/lib/i18n';
import { cn } from '@/lib/utils';

type Props = {
    title: string;
    description?: string;
    /** Buttons shown beside the title. */
    actions?: ReactNode;
    /** A link above the title (e.g. back to the list). */
    back?: ReactNode;
    pendingClaimsCount: number;
    children: ReactNode;
};

/** Frame of every admin page: section tabs, title, then the content. */
export function AdminShell({
    title,
    description,
    actions,
    back,
    pendingClaimsCount,
    children,
}: Props) {
    const t = useT();
    const { isCurrentUrl, isCurrentOrParentUrl } = useCurrentUrl();
    const tabs = [
        {
            href: '/admin',
            label: t('admin.nav_overview'),
            icon: LayoutDashboard,
            exact: true,
            badge: 0,
        },
        {
            href: '/admin/claims',
            label: t('admin.nav_claims'),
            icon: Inbox,
            exact: false,
            badge: pendingClaimsCount,
        },
        {
            href: '/admin/mosques',
            label: t('admin.nav_mosques'),
            icon: Building2,
            exact: false,
            badge: 0,
        },
        {
            href: '/admin/users',
            label: t('admin.nav_users'),
            icon: Users,
            exact: false,
            badge: 0,
        },
    ];

    return (
        <div className="space-y-6">
            <div className="flex items-center gap-2 text-sm font-medium text-primary">
                <ShieldCheck className="size-4" aria-hidden />
                {t('admin.eyebrow')}
            </div>

            <nav
                aria-label={t('admin.nav_label')}
                className="-mx-4 overflow-x-auto px-4 pb-1"
            >
                <div className="flex w-max gap-1 rounded-xl border bg-muted/40 p-1">
                    {tabs.map((tab) => {
                        const active = tab.exact
                            ? isCurrentUrl(tab.href)
                            : isCurrentOrParentUrl(tab.href);

                        return (
                            <Link
                                key={tab.href}
                                href={tab.href}
                                aria-current={active ? 'page' : undefined}
                                className={cn(
                                    'inline-flex items-center gap-2 rounded-lg px-3 py-2 text-sm font-medium whitespace-nowrap text-muted-foreground transition-colors hover:text-foreground',
                                    active &&
                                        'bg-background text-foreground shadow-sm',
                                )}
                            >
                                <tab.icon className="size-4" aria-hidden />
                                {tab.label}
                                {tab.badge > 0 && (
                                    <span
                                        className="rounded-full bg-gold px-1.5 py-0.5 text-[11px] leading-none font-semibold text-black tabular-nums"
                                        dir="ltr"
                                    >
                                        {tab.badge}
                                    </span>
                                )}
                            </Link>
                        );
                    })}
                </div>
            </nav>

            {back}

            <header className="flex flex-col gap-3 sm:flex-row sm:items-end sm:justify-between">
                <div className="min-w-0">
                    <h1 className="text-2xl font-semibold tracking-tight break-words">
                        {title}
                    </h1>
                    {description && (
                        <p className="mt-1 max-w-3xl text-muted-foreground">
                            {description}
                        </p>
                    )}
                </div>
                {actions && (
                    <div className="flex shrink-0 flex-wrap gap-2">
                        {actions}
                    </div>
                )}
            </header>

            {children}
        </div>
    );
}

/** "← Back to …" link used above admin detail pages. */
export function BackLink({ href, label }: { href: string; label: string }) {
    return (
        <Link
            href={href}
            className="inline-flex items-center gap-1.5 text-sm text-muted-foreground transition-colors hover:text-foreground"
        >
            <ArrowLeft className="size-4 rtl:rotate-180" aria-hidden />
            {label}
        </Link>
    );
}
