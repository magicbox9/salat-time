import { Link, usePage } from '@inertiajs/react';
import { Menu } from 'lucide-react';
import { Button } from '@/components/ui/button';
import {
    Sheet,
    SheetContent,
    SheetHeader,
    SheetTitle,
    SheetTrigger,
} from '@/components/ui/sheet';
import { useCurrentUrl } from '@/hooks/use-current-url';
import { useT } from '@/lib/i18n';
import { cn } from '@/lib/utils';
import { LocaleSwitcher } from './locale-switcher';
import { SITE_NAV } from './nav-items';
import { SiteLogo } from './site-logo';
import { ThemeToggle } from './theme-toggle';
import { UserNav } from './user-nav';

type Props = {
    /** Transparent header floating over a full-screen page (the globe). */
    overlay?: boolean;
};

export function SiteHeader({ overlay = false }: Props) {
    const { auth, dir } = usePage().props;
    const t = useT();
    const { isCurrentUrl } = useCurrentUrl();
    const items = SITE_NAV.filter((item) => !item.auth || auth.user);

    return (
        <header
            className={cn(
                'z-40 w-full',
                overlay
                    ? 'absolute inset-x-0 top-0 bg-gradient-to-b from-black/45 to-transparent text-white'
                    : 'sticky top-0 border-b bg-background/85 backdrop-blur',
            )}
        >
            <div className="mx-auto flex h-16 max-w-7xl items-center gap-4 px-4">
                <Sheet>
                    <SheetTrigger asChild>
                        <Button
                            variant="ghost"
                            size="icon"
                            className="md:hidden"
                            aria-label={t('site.menu')}
                        >
                            <Menu className="size-5" />
                        </Button>
                    </SheetTrigger>
                    <SheetContent side={dir === 'rtl' ? 'right' : 'left'} className="w-72">
                        <SheetHeader>
                            <SheetTitle>
                                <SiteLogo />
                            </SheetTitle>
                        </SheetHeader>
                        <nav className="mt-4 flex flex-col gap-1 px-2">
                            {items.map((item) => (
                                <Link
                                    key={item.href}
                                    href={item.href}
                                    className={cn(
                                        'flex items-center gap-3 rounded-md px-3 py-2 hover:bg-accent',
                                        isCurrentUrl(item.href) && 'bg-accent font-medium',
                                    )}
                                >
                                    <item.icon className="size-4" />
                                    {t(item.key)}
                                </Link>
                            ))}
                        </nav>
                    </SheetContent>
                </Sheet>

                <Link href="/" className="shrink-0">
                    <SiteLogo />
                </Link>

                <nav className="ms-4 hidden items-center gap-1 md:flex">
                    {items.map((item) => (
                        <Link
                            key={item.href}
                            href={item.href}
                            className={cn(
                                'rounded-md px-3 py-2 text-sm font-medium transition-colors',
                                overlay
                                    ? 'text-white/85 hover:bg-white/10 hover:text-white'
                                    : 'text-muted-foreground hover:bg-accent hover:text-foreground',
                                isCurrentUrl(item.href) &&
                                    (overlay ? 'bg-white/15 text-white' : 'bg-accent text-foreground'),
                            )}
                        >
                            {t(item.key)}
                        </Link>
                    ))}
                </nav>

                <div className="ms-auto flex items-center gap-1">
                    <LocaleSwitcher />
                    <ThemeToggle />
                    <UserNav />
                </div>
            </div>
        </header>
    );
}
