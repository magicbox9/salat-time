import { Link } from '@inertiajs/react';
import { HandCoins, Landmark, ReceiptText } from 'lucide-react';
import { useCurrentUrl } from '@/hooks/use-current-url';
import { useT } from '@/lib/i18n';
import { cn } from '@/lib/utils';

/** Fundraising sections of a mosque's management: campaigns, donations, accounts. */
export function FundraisingNav({
    mosqueSlug,
    toConfirm = 0,
}: {
    mosqueSlug: string;
    toConfirm?: number;
}) {
    const t = useT();
    const { currentUrl } = useCurrentUrl();
    const path = currentUrl.split('?')[0];
    const base = `/manage/${mosqueSlug}`;
    const items = [
        {
            href: `${base}/campaigns`,
            label: t('fundraising.nav_campaigns'),
            icon: HandCoins,
            badge: 0,
        },
        {
            href: `${base}/donations`,
            label: t('fundraising.nav_donations'),
            icon: ReceiptText,
            badge: toConfirm,
        },
        {
            href: `${base}/payouts`,
            label: t('fundraising.nav_payouts'),
            icon: Landmark,
            badge: 0,
        },
    ];

    return (
        <nav
            aria-label={t('fundraising.nav_label')}
            className="-mx-4 overflow-x-auto px-4 pb-1"
        >
            <div className="flex w-max gap-1 rounded-xl border bg-muted/40 p-1">
                {items.map((item) => {
                    const active = path.startsWith(item.href);

                    return (
                        <Link
                            key={item.href}
                            href={item.href}
                            aria-current={active ? 'page' : undefined}
                            className={cn(
                                'inline-flex items-center gap-2 rounded-lg px-3 py-2 text-sm font-medium whitespace-nowrap text-muted-foreground transition-colors hover:text-foreground',
                                active &&
                                    'bg-background text-foreground shadow-sm',
                            )}
                        >
                            <item.icon className="size-4" aria-hidden />
                            {item.label}
                            {item.badge > 0 && (
                                <span
                                    className="rounded-full bg-gold px-1.5 py-0.5 text-[11px] leading-none font-semibold text-black tabular-nums"
                                    dir="ltr"
                                >
                                    {item.badge}
                                </span>
                            )}
                        </Link>
                    );
                })}
            </div>
        </nav>
    );
}
