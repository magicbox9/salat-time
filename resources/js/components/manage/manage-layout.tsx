import { Head, Link } from '@inertiajs/react';
import { ArrowLeft, BadgeCheck, ExternalLink } from 'lucide-react';
import { SiteLogoMark } from '@/components/site/site-logo';
import { useT } from '@/lib/i18n';
import type { MosqueSummary } from '@/types/mosque';
import { ManagePillNav, ManageSidebarNav } from './manage-nav';

type Props = {
    mosque: MosqueSummary;
    title: string;
    description?: string;
    actions?: React.ReactNode;
    children: React.ReactNode;
};

function MosqueIdentity({ mosque }: { mosque: MosqueSummary }) {
    const t = useT();

    return (
        <div className="flex items-center gap-3">
            {mosque.logo_url ? (
                <img
                    src={mosque.logo_url}
                    alt=""
                    className="size-11 shrink-0 rounded-xl object-cover"
                />
            ) : (
                <SiteLogoMark className="size-11 rounded-xl" />
            )}
            <div className="min-w-0">
                <p className="flex items-center gap-1 text-sm font-semibold">
                    <span className="truncate">{mosque.name}</span>
                    {mosque.verified && (
                        <BadgeCheck
                            className="size-4 shrink-0 text-gold"
                            aria-label={t('mosque.verified')}
                        />
                    )}
                </p>
                <Link
                    href={`/mosques/${mosque.slug}`}
                    className="inline-flex items-center gap-1 text-xs text-muted-foreground hover:text-foreground hover:underline"
                >
                    {t('manage.view_site')}
                    <ExternalLink className="size-3" aria-hidden />
                </Link>
            </div>
        </div>
    );
}

/**
 * Every management page of a mosque: its sections in a sidebar (pills on
 * phones), the page title, then the page itself. Other modules' management
 * pages (display, campaigns, payouts) can use it too.
 */
export function ManageLayout({
    mosque,
    title,
    description,
    actions,
    children,
}: Props) {
    const t = useT();

    return (
        <div className="mx-auto w-full max-w-6xl">
            <Head title={`${title} · ${mosque.name}`} />
            <div className="lg:grid lg:grid-cols-[15rem_minmax(0,1fr)] lg:gap-10">
                <aside className="space-y-5 lg:sticky lg:top-24 lg:self-start">
                    <Link
                        href="/manage"
                        className="inline-flex items-center gap-1.5 text-sm text-muted-foreground hover:text-foreground"
                    >
                        <ArrowLeft
                            className="size-4 rtl:rotate-180"
                            aria-hidden
                        />
                        {t('manage.all_mosques')}
                    </Link>
                    <MosqueIdentity mosque={mosque} />
                    <div className="hidden lg:block">
                        <ManageSidebarNav slug={mosque.slug} />
                    </div>
                    <ManagePillNav slug={mosque.slug} className="lg:hidden" />
                </aside>

                <div className="mt-6 min-w-0 space-y-6 lg:mt-0">
                    <header className="flex flex-wrap items-end justify-between gap-3">
                        <div className="min-w-0">
                            <h1 className="text-2xl font-semibold tracking-tight">
                                {title}
                            </h1>
                            {description && (
                                <p className="mt-1 max-w-2xl text-sm text-muted-foreground">
                                    {description}
                                </p>
                            )}
                        </div>
                        {actions && (
                            <div className="flex flex-wrap gap-2">
                                {actions}
                            </div>
                        )}
                    </header>
                    {children}
                </div>
            </div>
        </div>
    );
}
