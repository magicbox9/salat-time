import { Head, Link } from '@inertiajs/react';
import { ArrowLeft, ExternalLink } from 'lucide-react';
import { SiteLogoMark } from '@/components/site/site-logo';
import { Button } from '@/components/ui/button';
import { useT } from '@/lib/i18n';
import type { MosqueSummary } from '@/types/mosque';
import { ManagePillNav } from './manage-nav';

type Props = {
    mosque: MosqueSummary;
    title: string;
    description?: string;
    actions?: React.ReactNode;
};

/**
 * A management header without the sidebar: mosque, title, the sections as
 * pills. Prefer <ManageLayout>, which wraps the page; this stays for pages
 * that draw their own frame.
 */
export function ManageHeader({ mosque, title, description, actions }: Props) {
    const t = useT();

    return (
        <header className="space-y-5">
            <Head title={`${title} · ${mosque.name}`} />
            <Link
                href="/manage"
                className="inline-flex items-center gap-1.5 text-sm text-muted-foreground hover:text-foreground"
            >
                <ArrowLeft className="size-4 rtl:rotate-180" aria-hidden />
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
                        <ExternalLink className="size-4" aria-hidden />
                        {t('manage.view_site')}
                    </Link>
                </Button>
            </div>

            <ManagePillNav slug={mosque.slug} />

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
