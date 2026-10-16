import { Head, Link, usePage } from '@inertiajs/react';
import { Building2, HandHeart, Heart, ShieldCheck } from 'lucide-react';
import { Card, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { useT } from '@/lib/i18n';

/** "My space": the signed-in visitor's hub. */
export default function Dashboard() {
    const t = useT();
    const { auth } = usePage().props;
    const tiles = [
        { href: '/me/mosques', title: t('site.nav_favorites'), icon: Heart },
        { href: '/prayers', title: t('site.nav_prayers'), icon: HandHeart },
        ...(auth.managedMosques.length > 0
            ? [{ href: '/manage', title: t('site.nav_manage'), icon: Building2 }]
            : []),
        ...(auth.isAdmin ? [{ href: '/admin', title: t('site.nav_admin'), icon: ShieldCheck }] : []),
    ];

    return (
        <>
            <Head title={t('site.dashboard_title')} />
            <h1 className="text-2xl font-semibold">{t('site.dashboard_title')}</h1>
            <p className="mt-1 text-muted-foreground">{t('site.dashboard_intro')}</p>
            <div className="mt-6 grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
                {tiles.map((tile) => (
                    <Link key={tile.href} href={tile.href}>
                        <Card className="h-full transition-colors hover:border-primary/50">
                            <CardHeader>
                                <tile.icon className="size-6 text-primary" />
                                <CardTitle>{tile.title}</CardTitle>
                                <CardDescription>{tile.href}</CardDescription>
                            </CardHeader>
                        </Card>
                    </Link>
                ))}
            </div>
        </>
    );
}
