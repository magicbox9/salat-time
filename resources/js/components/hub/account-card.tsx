import { Link } from '@inertiajs/react';
import { HandHeart, LogIn, UserPlus } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { useT } from '@/lib/i18n';

/**
 * In place of the tracker check-in: guests are invited to an account (their
 * mosque is only remembered in this browser), signed-in visitors whose
 * tracker is not open yet get a link to it.
 */
export function AccountCard({ guest }: { guest: boolean }) {
    const t = useT();

    return (
        <section
            aria-labelledby="hub-account"
            className="flex flex-col rounded-2xl border bg-card p-5"
        >
            <h2
                id="hub-account"
                className="flex items-center gap-2 font-semibold"
            >
                <HandHeart className="size-4 text-primary" aria-hidden />
                {t('hub.tracker_title')}
            </h2>
            <p className="mt-2 flex-1 text-sm text-muted-foreground">
                {guest ? t('hub.guest_text') : t('hub.tracker_intro')}
            </p>
            <div className="mt-4 flex flex-wrap gap-2">
                {guest ? (
                    <>
                        <Button asChild size="sm">
                            <Link href="/register">
                                <UserPlus />
                                {t('site.register')}
                            </Link>
                        </Button>
                        <Button asChild size="sm" variant="outline">
                            <Link href="/login">
                                <LogIn />
                                {t('site.log_in')}
                            </Link>
                        </Button>
                    </>
                ) : (
                    <Button asChild size="sm" variant="outline">
                        <Link href="/prayers">{t('hub.tracker_open')}</Link>
                    </Button>
                )}
            </div>
        </section>
    );
}
