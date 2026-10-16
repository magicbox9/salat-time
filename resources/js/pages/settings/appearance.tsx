import { Head } from '@inertiajs/react';
import AppearanceTabs from '@/components/appearance-tabs';
import Heading from '@/components/heading';
import { useT } from '@/lib/i18n';
import { edit as editAppearance } from '@/routes/appearance';

export default function Appearance() {
    const t = useT();

    return (
        <>
            <Head title={t('settings.appearance_title')} />

            <h1 className="sr-only">{t('settings.appearance_title')}</h1>

            <div className="space-y-6">
                <Heading
                    variant="small"
                    title={t('settings.appearance_title')}
                    description={t('settings.appearance_description')}
                />
                <AppearanceTabs />
            </div>
        </>
    );
}

// Breadcrumb titles are translation keys.
Appearance.layout = {
    breadcrumbs: [
        {
            title: 'settings.appearance_title',
            href: editAppearance(),
        },
    ],
};
