import { usePage } from '@inertiajs/react';
import { useEffect } from 'react';
import { SiteFooter } from '@/components/site/site-footer';
import { SiteHeader } from '@/components/site/site-header';
import { useFlashToast } from '@/hooks/use-flash-toast';

/** Keeps <html lang dir> in step with the chosen language. */
export function useDocumentLocale(): void {
    const { locale, dir } = usePage().props;

    useEffect(() => {
        document.documentElement.lang = locale;
        document.documentElement.dir = dir;
    }, [locale, dir]);
}

/** Public pages: header, centred content, footer. */
export default function SiteLayout({ children }: { children: React.ReactNode }) {
    useDocumentLocale();
    useFlashToast();

    return (
        <div className="flex min-h-svh flex-col bg-background">
            <SiteHeader />
            <main className="mx-auto w-full max-w-7xl flex-1 px-4 py-8">
                {children}
            </main>
            <SiteFooter />
        </div>
    );
}
