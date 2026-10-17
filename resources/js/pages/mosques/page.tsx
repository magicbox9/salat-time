import { Link, usePage } from '@inertiajs/react';
import { PencilLine } from 'lucide-react';
import { MarkdownContent } from '@/components/markdown-content';
import { ShareButton } from '@/components/mosque/article-parts';
import { formatInstant } from '@/components/mosque/calendar';
import { PreviewNotice } from '@/components/mosque/preview-notice';
import { SiteHead } from '@/components/mosque/site-head';
import { MosqueSiteShell } from '@/components/mosque/site-shell';
import type { SiteMeta, SiteShell } from '@/components/mosque/site-types';
import { Button } from '@/components/ui/button';
import { useT } from '@/lib/i18n';

type Props = {
    site: SiteShell;
    page: {
        id: number;
        title: string;
        slug: string;
        body_html: string;
        updated_at: string | null;
        published: boolean;
    };
    canManage: boolean;
    shareUrl: string;
    meta: SiteMeta;
};

/** A page of a mosque's site: About us, Courses, Contact… */
export default function MosqueSitePage({
    site,
    page,
    canManage,
    shareUrl,
    meta,
}: Props) {
    const t = useT();
    const { locale } = usePage().props;
    const editUrl = `/manage/${site.slug}/pages/${page.id}/edit`;

    return (
        <>
            <SiteHead meta={meta} />
            <MosqueSiteShell site={site} current={`page:${page.slug}`}>
                <article
                    className="mx-auto max-w-3xl space-y-6"
                    aria-labelledby="page-title"
                >
                    {!page.published && (
                        <PreviewNotice
                            editUrl={editUrl}
                            message={t('mosquesite.preview_page')}
                        />
                    )}
                    <header className="flex flex-wrap items-end justify-between gap-3 border-b pb-5">
                        <div className="min-w-0">
                            <h1
                                id="page-title"
                                dir="auto"
                                className="text-3xl font-semibold tracking-tight text-balance sm:text-4xl"
                            >
                                {page.title}
                            </h1>
                            {page.updated_at && (
                                <p className="mt-2 text-sm text-muted-foreground">
                                    {t('mosquesite.updated_on', {
                                        date: formatInstant(
                                            page.updated_at,
                                            locale,
                                            site.timezone,
                                            { dateStyle: 'long' },
                                        ),
                                    })}
                                </p>
                            )}
                        </div>
                        <div className="flex gap-2">
                            {canManage && (
                                <Button asChild size="sm" variant="ghost">
                                    <Link href={editUrl}>
                                        <PencilLine
                                            className="size-4"
                                            aria-hidden
                                        />
                                        {t('manage.edit')}
                                    </Link>
                                </Button>
                            )}
                            <ShareButton url={shareUrl} title={page.title} />
                        </div>
                    </header>
                    <MarkdownContent
                        html={page.body_html}
                        className="text-base text-foreground/90 sm:text-[1.0625rem]"
                    />
                </article>
            </MosqueSiteShell>
        </>
    );
}
