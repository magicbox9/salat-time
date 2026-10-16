import { useT } from '@/lib/i18n';
import { SiteLogo } from './site-logo';

export function SiteFooter() {
    const t = useT();

    return (
        <footer className="mt-16 border-t">
            <div className="mx-auto flex max-w-7xl flex-col gap-3 px-4 py-8 text-sm text-muted-foreground md:flex-row md:items-center md:justify-between">
                <SiteLogo className="text-foreground" />
                <p className="max-w-2xl">{t('site.footer_data')}</p>
                <p>{t('site.footer_made')}</p>
            </div>
        </footer>
    );
}
