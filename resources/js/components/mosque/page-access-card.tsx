import { Link } from '@inertiajs/react';
import { Building2, HandCoins, Hourglass, Settings2 } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { useT } from '@/lib/i18n';
import type { MosqueDetails, MosqueViewer } from './types';

/** "Manage this page" for its managers, or how a mosque's team can ask for access. */
export function PageAccessCard({
    mosque,
    viewer,
}: {
    mosque: MosqueDetails;
    viewer: MosqueViewer;
}) {
    const t = useT();

    if (viewer.can_manage) {
        return (
            <div className="rounded-2xl border border-primary/30 bg-primary/5 p-5">
                <p className="flex items-center gap-2 font-semibold">
                    <Settings2 className="size-4 text-primary" />
                    {t('mosque.you_manage')}
                </p>
                <p className="mt-1 text-sm text-muted-foreground">
                    {t('mosque.you_manage_hint')}
                </p>
                <Button asChild className="mt-4 w-full">
                    <Link href={`/manage/${mosque.slug}`}>
                        {t('mosque.manage_page')}
                    </Link>
                </Button>
            </div>
        );
    }

    return (
        <div className="rounded-2xl border bg-card p-5 shadow-xs">
            <p className="flex items-center gap-2 font-semibold">
                <Building2 className="size-4 text-primary" />
                {t('mosque.team_title')}
            </p>
            <p className="mt-1 text-sm text-muted-foreground">
                {t('mosque.team_body')}
            </p>
            {viewer.pending_claim ? (
                <p className="mt-4 flex items-center gap-2 rounded-lg bg-muted px-3 py-2 text-sm">
                    <Hourglass className="size-4 text-gold" />
                    {t('mosque.claim_pending')}
                </p>
            ) : (
                <Button asChild variant="outline" className="mt-4 w-full">
                    <Link
                        href={
                            viewer.signed_in
                                ? `/mosques/${mosque.slug}/claim`
                                : '/login'
                        }
                    >
                        {viewer.signed_in
                            ? t('mosque.request_manage')
                            : t('mosque.login_to_request')}
                    </Link>
                </Button>
            )}
        </div>
    );
}

/** Verified mosques only: giving will come later, through a payment provider. */
export function DonationsCard() {
    const t = useT();

    return (
        <div className="relative overflow-hidden rounded-2xl border border-gold/40 bg-gold/5 p-5">
            <HandCoins
                aria-hidden="true"
                className="absolute -end-3 -bottom-3 size-20 text-gold/15"
            />
            <p className="font-semibold">{t('mosque.donations_title')}</p>
            <p className="mt-1 text-sm text-muted-foreground">
                {t('mosque.donations_body')}
            </p>
            <span className="mt-3 inline-flex rounded-full bg-gold/20 px-2.5 py-0.5 text-xs font-medium">
                {t('mosque.coming_soon')}
            </span>
        </div>
    );
}
