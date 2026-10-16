import { Head, Link } from '@inertiajs/react';
import { Building2, FileCheck2, HandHeart, Heart, MapPinned, ShieldCheck } from 'lucide-react';
import { TodayTimes } from '@/components/prayer/today-times';
import { Button } from '@/components/ui/button';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { useT } from '@/lib/i18n';
import type { LiveTimes, MosqueSummary } from '@/types/mosque';
import { usePage } from '@inertiajs/react';

type Props = {
    mosque: (MosqueSummary & { live: Omit<LiveTimes, 'days'> }) | null;
    favoritesCount: number;
    tracker: {
        total_hasanat: number;
        streak: { current: number; best: number };
        today: { hasanat: number; prayed: number };
    };
    claims: { pending: number; total: number };
};

/** "My space": the signed-in visitor's mosque, today's prayers and requests. */
export default function Dashboard({ mosque, favoritesCount, tracker, claims }: Props) {
    const t = useT();
    const { auth } = usePage().props;

    return (
        <>
            <Head title={t('site.dashboard_title')} />
            <h1 className="text-2xl font-semibold">{t('site.dashboard_title')}</h1>
            <p className="mt-1 text-muted-foreground">{t('site.dashboard_intro')}</p>

            <div className="mt-6 grid gap-6 lg:grid-cols-3">
                <Card className="lg:col-span-2">
                    <CardHeader>
                        <CardDescription>{t('site.dash_my_mosque')}</CardDescription>
                        <CardTitle className="text-xl">
                            {mosque ? mosque.name : t('site.dash_open_globe')}
                        </CardTitle>
                        {mosque?.city && <p className="text-sm text-muted-foreground">{mosque.city}</p>}
                    </CardHeader>
                    <CardContent className="space-y-4">
                        {mosque ? (
                            <>
                                <TodayTimes
                                    today={mosque.live.today}
                                    tomorrow={mosque.live.tomorrow}
                                    timezone={mosque.live.timezone}
                                />
                                <Button variant="outline" asChild>
                                    <Link href={`/mosques/${mosque.slug}`}>{t('site.dash_open_page')}</Link>
                                </Button>
                            </>
                        ) : (
                            <>
                                <p className="text-muted-foreground">{t('site.dash_choose_mosque')}</p>
                                <Button asChild>
                                    <Link href="/">
                                        <MapPinned className="size-4" />
                                        {t('site.dash_open_globe')}
                                    </Link>
                                </Button>
                            </>
                        )}
                    </CardContent>
                </Card>

                <div className="flex flex-col gap-6">
                    <Card>
                        <CardHeader>
                            <CardDescription className="flex items-center gap-2">
                                <HandHeart className="size-4 text-primary" />
                                {t('site.dash_today_prayers')}
                            </CardDescription>
                            <CardTitle className="text-xl">
                                {t('site.dash_prayed_count', { count: tracker.today.prayed })}
                            </CardTitle>
                        </CardHeader>
                        <CardContent className="space-y-1 text-sm text-muted-foreground">
                            <p>{t('site.dash_hasanat_today', { count: tracker.today.hasanat })}</p>
                            <p>{t('site.dash_hasanat_total', { count: tracker.total_hasanat })}</p>
                            <p>{t('site.dash_streak', { count: tracker.streak.current })}</p>
                            <Button className="mt-3" size="sm" asChild>
                                <Link href="/prayers">{t('site.dash_open_tracker')}</Link>
                            </Button>
                        </CardContent>
                    </Card>

                    <Card>
                        <CardContent className="flex flex-col gap-2 pt-6 text-sm">
                            <Link href="/me/mosques" className="flex items-center justify-between gap-3 rounded-md px-1 py-1.5 hover:text-primary">
                                <span className="flex items-center gap-2">
                                    <Heart className="size-4 text-primary" />
                                    {t('site.nav_favorites')}
                                </span>
                                <span className="shrink-0 text-end text-xs text-muted-foreground">
                                    {t('site.dash_favorites', { count: favoritesCount })}
                                </span>
                            </Link>
                            <Link href="/me/claims" className="flex items-center justify-between gap-3 rounded-md px-1 py-1.5 hover:text-primary">
                                <span className="flex items-center gap-2">
                                    <FileCheck2 className="size-4 text-primary" />
                                    {t('site.nav_claims')}
                                </span>
                                <span className="shrink-0 text-end text-xs text-muted-foreground">
                                    {claims.total === 0
                                        ? t('site.dash_claims_none')
                                        : t('site.dash_claims_pending', { count: claims.pending })}
                                </span>
                            </Link>
                            {auth.managedMosques.length > 0 && (
                                <Link href="/manage" className="flex items-center justify-between gap-3 rounded-md px-1 py-1.5 hover:text-primary">
                                    <span className="flex items-center gap-2">
                                        <Building2 className="size-4 text-primary" />
                                        {t('site.nav_manage')}
                                    </span>
                                </Link>
                            )}
                            {auth.isAdmin && (
                                <Link href="/admin" className="flex items-center justify-between gap-3 rounded-md px-1 py-1.5 hover:text-primary">
                                    <span className="flex items-center gap-2">
                                        <ShieldCheck className="size-4 text-primary" />
                                        {t('site.nav_admin')}
                                    </span>
                                </Link>
                            )}
                        </CardContent>
                    </Card>
                </div>
            </div>
        </>
    );
}
