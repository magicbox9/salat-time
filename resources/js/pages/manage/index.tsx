import { Head, Link } from '@inertiajs/react';
import {
    BadgeCheck,
    Building2,
    FileText,
    MessagesSquare,
    PencilLine,
    Search,
} from 'lucide-react';
import { SiteLogoMark } from '@/components/site/site-logo';
import { Button } from '@/components/ui/button';
import { useT } from '@/lib/i18n';
import type { MosqueSummary } from '@/types/mosque';

type ManagedMosque = MosqueSummary & {
    role: string;
    published_count: number;
    drafts_count: number;
    comments_count: number;
};

type Props = { mosques: ManagedMosque[]; isAdmin: boolean };

/** "Mosques I manage". */
export default function ManageIndex({ mosques, isAdmin }: Props) {
    const t = useT();

    return (
        <>
            <Head title={t('manage.title')} />
            <div className="mx-auto max-w-4xl space-y-6">
                <div>
                    <h1 className="text-2xl font-semibold tracking-tight">
                        {t('manage.title')}
                    </h1>
                    <p className="mt-1 text-muted-foreground">
                        {t('manage.intro')}
                    </p>
                </div>

                {mosques.length === 0 ? (
                    <div className="rounded-2xl border border-dashed px-6 py-12 text-center">
                        <Building2 className="mx-auto size-8 text-muted-foreground/60" />
                        <p className="mt-3 font-medium">
                            {t('manage.empty_title')}
                        </p>
                        <p className="mx-auto mt-1 max-w-md text-sm text-muted-foreground">
                            {isAdmin
                                ? t('manage.empty_admin')
                                : t('manage.empty_body')}
                        </p>
                        <Button asChild variant="outline" className="mt-5">
                            <Link href="/">
                                <Search className="size-4" />
                                {t('manage.find_mosque')}
                            </Link>
                        </Button>
                    </div>
                ) : (
                    <ul className="grid gap-4 sm:grid-cols-2">
                        {mosques.map((mosque) => (
                            <li
                                key={mosque.id}
                                className="flex flex-col rounded-2xl border bg-card p-5 shadow-xs"
                            >
                                <div className="flex items-start gap-3">
                                    {mosque.logo_url ? (
                                        <img
                                            src={mosque.logo_url}
                                            alt=""
                                            className="size-12 rounded-xl object-cover"
                                        />
                                    ) : (
                                        <SiteLogoMark className="size-12 rounded-xl" />
                                    )}
                                    <div className="min-w-0 flex-1">
                                        <p className="flex items-center gap-1.5 font-semibold">
                                            <span className="truncate">
                                                {mosque.name}
                                            </span>
                                            {mosque.verified && (
                                                <BadgeCheck className="size-4 shrink-0 text-gold" />
                                            )}
                                        </p>
                                        <p className="truncate text-sm text-muted-foreground">
                                            {[mosque.postcode, mosque.city]
                                                .filter(Boolean)
                                                .join(' ')}
                                        </p>
                                        <p className="mt-1 text-xs text-muted-foreground">
                                            {t(
                                                `manage.role_${mosque.role === 'editor' ? 'editor' : 'owner'}`,
                                            )}
                                        </p>
                                    </div>
                                </div>
                                <dl className="mt-4 grid grid-cols-3 gap-2 text-center">
                                    <Stat
                                        icon={FileText}
                                        label={t('manage.stat_published')}
                                        value={mosque.published_count}
                                    />
                                    <Stat
                                        icon={PencilLine}
                                        label={t('manage.stat_drafts')}
                                        value={mosque.drafts_count}
                                    />
                                    <Stat
                                        icon={MessagesSquare}
                                        label={t('manage.stat_comments')}
                                        value={mosque.comments_count}
                                    />
                                </dl>
                                <div className="mt-4 flex flex-wrap gap-2">
                                    <Button asChild size="sm">
                                        <Link href={`/manage/${mosque.slug}`}>
                                            {t('manage.open')}
                                        </Link>
                                    </Button>
                                    <Button asChild size="sm" variant="outline">
                                        <Link
                                            href={`/manage/${mosque.slug}/posts/create`}
                                        >
                                            {t('manage.new_post')}
                                        </Link>
                                    </Button>
                                    <Button asChild size="sm" variant="ghost">
                                        <Link href={`/mosques/${mosque.slug}`}>
                                            {t('manage.view_site')}
                                        </Link>
                                    </Button>
                                </div>
                            </li>
                        ))}
                    </ul>
                )}
            </div>
        </>
    );
}

function Stat({
    icon: Icon,
    label,
    value,
}: {
    icon: typeof FileText;
    label: string;
    value: number;
}) {
    return (
        <div className="rounded-xl bg-muted/60 px-2 py-2">
            <dt className="flex items-center justify-center gap-1 text-[11px] text-muted-foreground">
                <Icon className="size-3.5" />
                {label}
            </dt>
            <dd className="text-lg font-semibold tabular-nums">{value}</dd>
        </div>
    );
}
