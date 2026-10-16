import { Link } from '@inertiajs/react';
import { LocaleSwitcher } from '@/components/site/locale-switcher';
import { SiteLogo } from '@/components/site/site-logo';
import { ThemeToggle } from '@/components/site/theme-toggle';
import { useT } from '@/lib/i18n';
import { home } from '@/routes';
import type { AuthLayoutProps } from '@/types';

/**
 * Salat Time sign-in frame: brand and language/theme controls on top, the
 * form in a card under a soft dawn glow. Title and description arrive
 * already translated (see layouts/auth-layout.tsx).
 */
export default function AuthSimpleLayout({
    children,
    title,
    description,
}: AuthLayoutProps) {
    const t = useT();

    return (
        <div className="relative flex min-h-svh flex-col overflow-hidden bg-background">
            <div
                aria-hidden="true"
                className="pointer-events-none absolute inset-x-0 top-0 h-96 bg-[radial-gradient(ellipse_at_top,var(--accent),transparent_70%)]"
            />

            <header className="relative z-10 mx-auto flex h-16 w-full max-w-5xl items-center justify-between gap-4 px-4">
                <Link
                    href={home()}
                    aria-label={t('auth.back_home')}
                    className="rounded-md focus-visible:ring-[3px] focus-visible:ring-ring focus-visible:outline-none"
                >
                    <SiteLogo />
                </Link>
                <div className="flex items-center gap-1">
                    <LocaleSwitcher />
                    <ThemeToggle />
                </div>
            </header>

            <main className="relative z-10 flex flex-1 items-center justify-center px-4 py-8">
                <div className="w-full max-w-sm rounded-2xl border bg-card p-6 text-card-foreground shadow-sm sm:p-8">
                    <div className="mb-8 space-y-2 text-center">
                        <h1 className="text-xl font-semibold tracking-tight">
                            {title}
                        </h1>
                        {description && (
                            <p className="text-sm text-balance text-muted-foreground">
                                {description}
                            </p>
                        )}
                    </div>
                    {children}
                </div>
            </main>

            <footer className="relative z-10 px-4 pb-6 text-center text-xs text-muted-foreground">
                {t('auth.layout_footer')}
            </footer>
        </div>
    );
}
