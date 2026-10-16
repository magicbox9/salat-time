import { Head, Link } from '@inertiajs/react';
import {
    ArrowLeft,
    ExternalLink,
    FileText,
    MessagesSquare,
    Store,
} from 'lucide-react';
import { SiteLogoMark } from '@/components/site/site-logo';
import { Button } from '@/components/ui/button';
import { useCurrentUrl } from '@/hooks/use-current-url';
import { useT } from '@/lib/i18n';
import { cn } from '@/lib/utils';
import type { MosqueSummary } from '@/types/mosque';

type Props = {
    mosque: MosqueSummary;
    title: string;
    description?: string;
    actions?: React.ReactNode;
};

/** Shared header of the management pages: mosque, sections, link to the public page. */
export function ManageHeader({ mosque, title, description, actions }: Props) {
    const t = useT();
    const { currentUrl } = useCurrentUrl();
    const base = `/manage/${mosque.slug}`;
    const sections = [
        {
            href: base,
            label: t('manage.nav_details'),
            icon: Store,
            exact: true,
        },
        { href: `${base}/posts`, label: t('manage.nav_posts'), icon: FileText },
        {
            href: `${base}/comments`,
            label: t('manage.nav_comments'),
            icon: MessagesSquare,
        },
    ];
    const path = currentUrl.split('?')[0];

    return (
        <header className="space-y-5">
            <Head title={`${title} · ${mosque.name}`} />
            <Link
                href="/manage"
                className="inline-flex items-center gap-1.5 text-sm text-muted-foreground hover:text-foreground"
            >
                <ArrowLeft className="size-4 rtl:rotate-180" />
                {t('manage.all_mosques')}
            </Link>

            <div className="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
                <div className="flex min-w-0 items-center gap-3">
                    {mosque.logo_url ? (
                        <img
                            src={mosque.logo_url}
                            alt=""
                            className="size-12 shrink-0 rounded-xl object-cover"
                        />
                    ) : (
                        <SiteLogoMark className="size-12 rounded-xl" />
                    )}
                    <div className="min-w-0">
                        <p className="truncate text-sm text-muted-foreground">
                            {mosque.name}
                        </p>
                        <h1 className="text-2xl font-semibold tracking-tight">
                            {title}
                        </h1>
                    </div>
                </div>
                <Button asChild variant="outline" size="sm">
                    <Link href={`/mosques/${mosque.slug}`}>
                        <ExternalLink className="size-4" />
                        {t('manage.view_page')}
                    </Link>
                </Button>
            </div>

            <nav
                className="-mb-px flex gap-1 overflow-x-auto border-b"
                aria-label={t('manage.sections')}
            >
                {sections.map((section) => {
                    const active = section.exact
                        ? path === section.href
                        : path.startsWith(section.href);

                    return (
                        <Link
                            key={section.href}
                            href={section.href}
                            aria-current={active ? 'page' : undefined}
                            className={cn(
                                'flex shrink-0 items-center gap-2 border-b-2 px-3 py-2.5 text-sm font-medium transition-colors',
                                active
                                    ? 'border-primary text-foreground'
                                    : 'border-transparent text-muted-foreground hover:text-foreground',
                            )}
                        >
                            <section.icon className="size-4" />
                            {section.label}
                        </Link>
                    );
                })}
            </nav>

            {(description || actions) && (
                <div className="flex flex-wrap items-center justify-between gap-3">
                    {description && (
                        <p className="text-sm text-muted-foreground">
                            {description}
                        </p>
                    )}
                    {actions && (
                        <div className="ms-auto flex gap-2">{actions}</div>
                    )}
                </div>
            )}
        </header>
    );
}
