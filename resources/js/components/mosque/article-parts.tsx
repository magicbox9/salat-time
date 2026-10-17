import { Link, usePage } from '@inertiajs/react';
import {
    ArrowLeft,
    ArrowRight,
    Download,
    FileText,
    Share2,
} from 'lucide-react';
import { toast } from 'sonner';
import { Button } from '@/components/ui/button';
import { useClipboard } from '@/hooks/use-clipboard';
import { intlLocale, useT } from '@/lib/i18n';
import type { AttachmentData, Neighbour } from './site-types';

function fileSize(bytes: number, locale: string): string {
    const units = ['byte', 'kilobyte', 'megabyte'] as const;
    let value = bytes;
    let unit = 0;

    while (value >= 1024 && unit < units.length - 1) {
        value /= 1024;
        unit++;
    }

    // "1.2 MB", "1,2 Mo", "1.2 م.ب": units in the visitor's language.
    return new Intl.NumberFormat(intlLocale(locale), {
        style: 'unit',
        unit: units[unit],
        unitDisplay: 'short',
        maximumFractionDigits: unit === 0 ? 0 : 1,
    }).format(value);
}

/** The PDF attached to a post (khutbah text, programme). */
export function ArticleAttachment({ file }: { file: AttachmentData }) {
    const t = useT();
    const { locale } = usePage().props;

    return (
        <a
            href={file.url}
            download={file.name}
            className="group flex items-center gap-4 rounded-2xl border bg-card p-4 shadow-xs transition-colors outline-none hover:border-[var(--site-accent)]/50 focus-visible:ring-2 focus-visible:ring-[var(--site-accent)]/50"
        >
            <span className="flex size-12 shrink-0 items-center justify-center rounded-xl bg-red-500/10 text-red-700 dark:text-red-300">
                <FileText className="size-6" aria-hidden />
            </span>
            <span className="min-w-0 flex-1">
                <span className="block truncate font-medium" dir="auto">
                    {file.name}
                </span>
                <span className="block text-xs text-muted-foreground">
                    PDF
                    {file.size !== null && (
                        <span dir="ltr"> · {fileSize(file.size, locale)}</span>
                    )}
                </span>
            </span>
            <span className="inline-flex items-center gap-1.5 text-sm font-medium text-[var(--site-accent-ink)]">
                <Download className="size-4" aria-hidden />
                <span className="hidden sm:inline">
                    {t('mosquesite.download')}
                </span>
            </span>
        </a>
    );
}

/** Shares the page (the phone's share sheet, or a copied link). */
export function ShareButton({ url, title }: { url: string; title: string }) {
    const t = useT();
    const [, copy] = useClipboard();

    const share = async () => {
        if (typeof navigator !== 'undefined' && navigator.share) {
            try {
                await navigator.share({ title, url });
            } catch {
                // Closing the share sheet is not an error.
            }

            return;
        }

        if (await copy(url)) {
            toast.success(t('mosque.link_copied'));
        } else {
            toast.error(t('site.error_generic'));
        }
    };

    return (
        <Button variant="outline" size="sm" onClick={share}>
            <Share2 className="size-4" aria-hidden />
            {t('mosque.share')}
        </Button>
    );
}

/** The articles published just before and after this one. */
export function ArticleNeighbours({
    previous,
    next,
}: {
    previous: Neighbour;
    next: Neighbour;
}) {
    const t = useT();

    if (!previous && !next) {
        return null;
    }

    const card = (item: NonNullable<Neighbour>, newer: boolean) => (
        <Link
            href={item.url}
            className={`group flex h-full flex-col rounded-2xl border bg-card p-4 transition-colors outline-none hover:border-[var(--site-accent)]/50 focus-visible:ring-2 focus-visible:ring-[var(--site-accent)]/50 ${newer ? 'items-end text-end' : ''}`}
        >
            <span className="flex items-center gap-1 text-xs text-muted-foreground">
                {!newer && (
                    <ArrowLeft
                        className="size-3.5 rtl:rotate-180"
                        aria-hidden
                    />
                )}
                {newer
                    ? t('mosquesite.newer_post')
                    : t('mosquesite.older_post')}
                {newer && (
                    <ArrowRight
                        className="size-3.5 rtl:rotate-180"
                        aria-hidden
                    />
                )}
            </span>
            <span
                dir="auto"
                className="mt-1 line-clamp-2 font-medium group-hover:underline group-hover:underline-offset-4"
            >
                {item.title}
            </span>
        </Link>
    );

    return (
        <nav
            aria-label={t('mosquesite.more_posts')}
            className="grid gap-3 sm:grid-cols-2"
        >
            <div>{previous && card(previous, false)}</div>
            <div>{next && card(next, true)}</div>
        </nav>
    );
}
