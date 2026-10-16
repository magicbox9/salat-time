import { Head } from '@inertiajs/react';
import { SiteHeader } from '@/components/site/site-header';
import { useDocumentLocale } from '@/layouts/site-layout';
import { useT } from '@/lib/i18n';

/** Placeholder until the globe search lands. */
export default function Home() {
    useDocumentLocale();
    const t = useT();

    return (
        <div className="relative min-h-svh bg-[oklch(0.17_0.025_200)] text-white">
            <Head title={t('site.nav_mosques')} />
            <SiteHeader overlay />
            <div className="flex min-h-svh items-center justify-center px-4">
                <h1 className="text-center text-3xl font-semibold">{t('site.tagline')}</h1>
            </div>
        </div>
    );
}
