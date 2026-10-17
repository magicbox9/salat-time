import { Link } from '@inertiajs/react';
import { Check, ChevronRight } from 'lucide-react';
import { useT } from '@/lib/i18n';
import { cn } from '@/lib/utils';

export type Checklist = {
    logo: boolean;
    cover: boolean;
    tagline: boolean;
    description: boolean;
    contact: boolean;
    social: boolean;
    page: boolean;
    khutbah: boolean;
};

/** "Complete your site": what is done, what is left, each a link to where it is done. */
export function SiteChecklist({
    slug,
    checklist,
}: {
    slug: string;
    checklist: Checklist;
}) {
    const t = useT();
    const base = `/manage/${slug}`;
    const items: { key: keyof Checklist; href: string }[] = [
        { key: 'logo', href: `${base}/details` },
        { key: 'cover', href: `${base}/details` },
        { key: 'tagline', href: `${base}/details` },
        { key: 'description', href: `${base}/details` },
        { key: 'contact', href: `${base}/details` },
        { key: 'social', href: `${base}/details` },
        { key: 'page', href: `${base}/pages/create` },
        { key: 'khutbah', href: `${base}/posts/create` },
    ];
    const done = items.filter((item) => checklist[item.key]).length;
    const percent = Math.round((done / items.length) * 100);

    return (
        <section
            aria-labelledby="site-checklist"
            className="rounded-2xl border bg-card p-5 shadow-xs"
        >
            <div className="flex items-center justify-between gap-3">
                <h2 id="site-checklist" className="font-semibold">
                    {t('manage.checklist_title')}
                </h2>
                <span
                    className="text-sm text-muted-foreground tabular-nums"
                    dir="ltr"
                >
                    {done}/{items.length}
                </span>
            </div>
            <div
                className="mt-3 h-1.5 overflow-hidden rounded-full bg-muted"
                role="progressbar"
                aria-valuenow={percent}
                aria-valuemin={0}
                aria-valuemax={100}
                aria-label={t('manage.checklist_title')}
            >
                <div
                    className="h-full rounded-full bg-gold transition-[width] duration-700 motion-reduce:transition-none"
                    style={{ width: `${percent}%` }}
                />
            </div>
            <ul className="mt-4 grid gap-1 sm:grid-cols-2">
                {items.map((item) => {
                    const ok = checklist[item.key];

                    return (
                        <li key={item.key}>
                            <Link
                                href={item.href}
                                className="group flex items-center gap-2.5 rounded-lg px-2 py-1.5 text-sm transition-colors hover:bg-accent/60"
                            >
                                <span
                                    className={cn(
                                        'flex size-5 shrink-0 items-center justify-center rounded-full border',
                                        ok
                                            ? 'border-transparent bg-primary text-primary-foreground'
                                            : 'border-dashed',
                                    )}
                                >
                                    {ok && (
                                        <Check className="size-3" aria-hidden />
                                    )}
                                </span>
                                <span
                                    className={cn(
                                        'flex-1',
                                        ok &&
                                            'text-muted-foreground line-through decoration-muted-foreground/40',
                                    )}
                                >
                                    {t(`manage.checklist_${item.key}`)}
                                </span>
                                {!ok && (
                                    <ChevronRight
                                        className="size-4 text-muted-foreground rtl:rotate-180"
                                        aria-hidden
                                    />
                                )}
                                <span className="sr-only">
                                    {ok ? t('manage.done') : t('manage.to_do')}
                                </span>
                            </Link>
                        </li>
                    );
                })}
            </ul>
        </section>
    );
}
