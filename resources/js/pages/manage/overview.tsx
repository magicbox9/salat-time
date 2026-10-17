import { Link, usePage } from '@inertiajs/react';
import {
    ExternalLink,
    FilePlus2,
    HandCoins,
    Landmark,
    MonitorPlay,
    PencilLine,
    Plus,
} from 'lucide-react';
import type { LucideIcon } from 'lucide-react';
import { ManageLayout } from '@/components/manage/manage-layout';
import { SiteChecklist } from '@/components/manage/site-checklist';
import type { Checklist } from '@/components/manage/site-checklist';
import { StatusBadge } from '@/components/manage/status-badge';
import type { PublishStatus } from '@/components/manage/status-badge';
import { timeAgo } from '@/components/mosque/post-type-badge';
import type { PostCategoryRef } from '@/components/mosque/site-types';
import { Button } from '@/components/ui/button';
import { useT } from '@/lib/i18n';
import type { MosqueSummary } from '@/types/mosque';

type Props = {
    mosque: MosqueSummary & {
        cover_url: string | null;
        tagline: string | null;
    };
    stats: {
        published: number;
        scheduled: number;
        drafts: number;
        pages: number;
        categories: number;
        comments: number;
        comments_hidden: number;
        comments_recent: number;
    };
    checklist: Checklist;
    recent: {
        id: number;
        title: string;
        category: PostCategoryRef | null;
        status: PublishStatus;
        published_at: string | null;
        updated_at: string | null;
    }[];
};

function Stat({
    label,
    value,
    href,
}: {
    label: string;
    value: number;
    href: string;
}) {
    return (
        <Link
            href={href}
            className="rounded-2xl border bg-card p-4 shadow-xs transition-colors hover:border-primary/40"
        >
            <p className="text-xs text-muted-foreground">{label}</p>
            <p className="mt-1 text-2xl font-semibold tabular-nums">{value}</p>
        </Link>
    );
}

function Shortcut({
    href,
    icon: Icon,
    title,
    body,
}: {
    href: string;
    icon: LucideIcon;
    title: string;
    body: string;
}) {
    return (
        <Link
            href={href}
            className="group flex items-start gap-3 rounded-2xl border bg-card p-4 shadow-xs transition-colors hover:border-primary/40"
        >
            <span className="flex size-10 shrink-0 items-center justify-center rounded-xl bg-primary/10 text-primary">
                <Icon className="size-5" aria-hidden />
            </span>
            <span className="min-w-0">
                <span className="block font-medium group-hover:underline group-hover:underline-offset-4">
                    {title}
                </span>
                <span className="block text-sm text-muted-foreground">
                    {body}
                </span>
            </span>
        </Link>
    );
}

/** Where a mosque's site stands, and what to do next. */
export default function ManageOverview({
    mosque,
    stats,
    checklist,
    recent,
}: Props) {
    const t = useT();
    const { locale } = usePage().props;
    const base = `/manage/${mosque.slug}`;

    return (
        <ManageLayout
            mosque={mosque}
            title={t('manage.overview_title')}
            description={t('manage.overview_intro')}
            actions={
                <>
                    <Button asChild variant="outline" size="sm">
                        <Link href={`/mosques/${mosque.slug}`}>
                            <ExternalLink className="size-4" aria-hidden />
                            {t('manage.view_site')}
                        </Link>
                    </Button>
                    <Button asChild size="sm">
                        <Link href={`${base}/posts/create`}>
                            <Plus className="size-4" aria-hidden />
                            {t('manage.new_post')}
                        </Link>
                    </Button>
                </>
            }
        >
            <div className="grid grid-cols-2 gap-3 sm:grid-cols-4">
                <Stat
                    label={t('manage.stat_published')}
                    value={stats.published}
                    href={`${base}/posts?status=published`}
                />
                <Stat
                    label={t('manage.stat_scheduled')}
                    value={stats.scheduled}
                    href={`${base}/posts?status=scheduled`}
                />
                <Stat
                    label={t('manage.stat_drafts')}
                    value={stats.drafts}
                    href={`${base}/posts?status=drafts`}
                />
                <Stat
                    label={t('manage.stat_pages')}
                    value={stats.pages}
                    href={`${base}/pages`}
                />
            </div>

            <div className="grid gap-6 lg:grid-cols-[minmax(0,1.2fr)_minmax(0,1fr)]">
                <SiteChecklist slug={mosque.slug} checklist={checklist} />

                <section
                    aria-labelledby="recent-posts"
                    className="rounded-2xl border bg-card p-5 shadow-xs"
                >
                    <div className="flex items-center justify-between gap-3">
                        <h2 id="recent-posts" className="font-semibold">
                            {t('manage.recent_posts')}
                        </h2>
                        <Link
                            href={`${base}/posts`}
                            className="text-sm text-primary hover:underline"
                        >
                            {t('manage.see_all')}
                        </Link>
                    </div>
                    {recent.length === 0 ? (
                        <p className="mt-3 text-sm text-muted-foreground">
                            {t('manage.no_posts_hint')}
                        </p>
                    ) : (
                        <ul className="mt-3 space-y-1">
                            {recent.map((post) => (
                                <li key={post.id}>
                                    <Link
                                        href={`${base}/posts/${post.id}/edit`}
                                        className="group flex items-center gap-3 rounded-lg px-2 py-2 transition-colors hover:bg-accent/60"
                                    >
                                        <span className="min-w-0 flex-1">
                                            <span
                                                dir="auto"
                                                className="block truncate text-sm font-medium"
                                            >
                                                {post.title}
                                            </span>
                                            <span className="flex flex-wrap items-center gap-2 text-xs text-muted-foreground">
                                                <StatusBadge
                                                    status={post.status}
                                                />
                                                {post.category?.name}
                                                {post.updated_at && (
                                                    <span>
                                                        {timeAgo(
                                                            post.updated_at,
                                                            locale,
                                                        )}
                                                    </span>
                                                )}
                                            </span>
                                        </span>
                                        <PencilLine
                                            className="size-4 shrink-0 text-muted-foreground opacity-0 transition-opacity group-hover:opacity-100"
                                            aria-hidden
                                        />
                                    </Link>
                                </li>
                            ))}
                        </ul>
                    )}
                    <p className="mt-4 border-t pt-3 text-xs text-muted-foreground">
                        {t('manage.comments_summary', {
                            total: stats.comments,
                            recent: stats.comments_recent,
                            hidden: stats.comments_hidden,
                        })}
                    </p>
                </section>
            </div>

            <section aria-labelledby="shortcuts" className="space-y-3">
                <h2 id="shortcuts" className="font-semibold">
                    {t('manage.shortcuts_title')}
                </h2>
                <div className="grid gap-3 md:grid-cols-2 xl:grid-cols-4">
                    <Shortcut
                        href={`${base}/pages/create`}
                        icon={FilePlus2}
                        title={t('manage.new_page')}
                        body={t('manage.shortcut_page')}
                    />
                    <Shortcut
                        href={`${base}/display`}
                        icon={MonitorPlay}
                        title={t('manage.nav_display')}
                        body={t('manage.shortcut_display')}
                    />
                    <Shortcut
                        href={`${base}/campaigns`}
                        icon={HandCoins}
                        title={t('manage.nav_campaigns')}
                        body={t('manage.shortcut_campaigns')}
                    />
                    <Shortcut
                        href={`${base}/payouts`}
                        icon={Landmark}
                        title={t('manage.nav_payouts')}
                        body={t('manage.shortcut_payouts')}
                    />
                </div>
            </section>
        </ManageLayout>
    );
}
