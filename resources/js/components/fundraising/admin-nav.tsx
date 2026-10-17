import { Link } from '@inertiajs/react';
import { useCurrentUrl } from '@/hooks/use-current-url';
import { useT } from '@/lib/i18n';
import { cn } from '@/lib/utils';

/** Overview · Campaigns · Accounts, inside the admin's fundraising section. */
export function AdminFundraisingNav() {
    const t = useT();
    const { currentUrl } = useCurrentUrl();
    const path = currentUrl.split('?')[0];
    const items = [
        {
            href: '/admin/fundraising',
            label: t('fundraising.admin_overview'),
            exact: true,
        },
        {
            href: '/admin/fundraising/campaigns',
            label: t('fundraising.admin_campaigns'),
            exact: false,
        },
        {
            href: '/admin/fundraising/payouts',
            label: t('fundraising.admin_payouts'),
            exact: false,
        },
    ];

    return (
        <nav
            aria-label={t('fundraising.admin_nav')}
            className="flex flex-wrap gap-x-5 gap-y-2 border-b"
        >
            {items.map((item) => {
                const active = item.exact
                    ? path === item.href
                    : path.startsWith(item.href);

                return (
                    <Link
                        key={item.href}
                        href={item.href}
                        aria-current={active ? 'page' : undefined}
                        className={cn(
                            '-mb-px border-b-2 pb-2.5 text-sm font-medium transition-colors',
                            active
                                ? 'border-primary text-foreground'
                                : 'border-transparent text-muted-foreground hover:text-foreground',
                        )}
                    >
                        {item.label}
                    </Link>
                );
            })}
        </nav>
    );
}
