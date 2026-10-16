import { Link, router, usePage } from '@inertiajs/react';
import {
    Building2,
    FileCheck2,
    Heart,
    LayoutDashboard,
    LogOut,
    Settings,
    ShieldCheck,
} from 'lucide-react';
import { Avatar, AvatarFallback } from '@/components/ui/avatar';
import { Button } from '@/components/ui/button';
import {
    DropdownMenu,
    DropdownMenuContent,
    DropdownMenuItem,
    DropdownMenuLabel,
    DropdownMenuSeparator,
    DropdownMenuTrigger,
} from '@/components/ui/dropdown-menu';
import { useInitials } from '@/hooks/use-initials';
import { useT } from '@/lib/i18n';

export function UserNav() {
    const { auth } = usePage().props;
    const t = useT();
    const getInitials = useInitials();

    if (!auth.user) {
        return (
            <div className="flex items-center gap-1">
                <Button variant="ghost" asChild>
                    <Link href="/login">{t('site.log_in')}</Link>
                </Button>
                <Button asChild className="hidden sm:inline-flex">
                    <Link href="/register">{t('site.register')}</Link>
                </Button>
            </div>
        );
    }

    const item = (href: string, label: string, Icon: typeof Heart) => (
        <DropdownMenuItem asChild>
            <Link href={href} className="flex w-full items-center gap-2">
                <Icon className="size-4" />
                {label}
            </Link>
        </DropdownMenuItem>
    );

    return (
        <DropdownMenu>
            <DropdownMenuTrigger asChild>
                <Button variant="ghost" size="icon" className="rounded-full">
                    <Avatar className="size-8">
                        <AvatarFallback className="bg-primary/15 text-primary">
                            {getInitials(auth.user.name)}
                        </AvatarFallback>
                    </Avatar>
                </Button>
            </DropdownMenuTrigger>
            <DropdownMenuContent align="end" className="w-60">
                <DropdownMenuLabel className="font-normal">
                    <div className="truncate font-medium">{auth.user.name}</div>
                    <div className="truncate text-xs text-muted-foreground">
                        {auth.user.email}
                    </div>
                </DropdownMenuLabel>
                <DropdownMenuSeparator />
                {item('/dashboard', t('site.nav_my_space'), LayoutDashboard)}
                {item('/me/mosques', t('site.nav_favorites'), Heart)}
                {item('/me/claims', t('site.nav_claims'), FileCheck2)}
                {auth.managedMosques.length > 0 &&
                    item('/manage', t('site.nav_manage'), Building2)}
                {auth.isAdmin && item('/admin', t('site.nav_admin'), ShieldCheck)}
                {item('/settings/profile', t('site.nav_settings'), Settings)}
                <DropdownMenuSeparator />
                <DropdownMenuItem
                    onSelect={() => {
                        router.flushAll();
                        router.post('/logout');
                    }}
                    className="flex items-center gap-2"
                    data-test="logout-button"
                >
                    <LogOut className="size-4" />
                    {t('site.log_out')}
                </DropdownMenuItem>
            </DropdownMenuContent>
        </DropdownMenu>
    );
}
