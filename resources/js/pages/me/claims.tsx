import { Head, Link } from '@inertiajs/react';
import { Inbox, MapPinned } from 'lucide-react';
import { ClaimCard } from '@/components/claims/claim-card';
import type { ClaimantClaim } from '@/components/claims/types';
import { Button } from '@/components/ui/button';
import { useT } from '@/lib/i18n';

/** /me/claims — the user's requests to manage a mosque. */
export default function MyClaims({ claims }: { claims: ClaimantClaim[] }) {
    const t = useT();

    return (
        <>
            <Head title={t('claims.mine_title')} />

            <header className="mb-8">
                <h1 className="text-2xl font-semibold tracking-tight">
                    {t('claims.mine_title')}
                </h1>
                <p className="mt-1 max-w-2xl text-muted-foreground">
                    {t('claims.mine_intro')}
                </p>
            </header>

            {claims.length === 0 ? (
                <div className="flex flex-col items-center rounded-xl border border-dashed px-6 py-14 text-center">
                    <span className="flex size-12 items-center justify-center rounded-full bg-primary/10 text-primary">
                        <Inbox className="size-6" aria-hidden />
                    </span>
                    <h2 className="mt-4 text-lg font-semibold">
                        {t('claims.mine_empty_title')}
                    </h2>
                    <p className="mt-1 max-w-md text-sm text-muted-foreground">
                        {t('claims.mine_empty_text')}
                    </p>
                    <Button asChild className="mt-6">
                        <Link href="/">
                            <MapPinned />
                            {t('claims.find_mosque')}
                        </Link>
                    </Button>
                </div>
            ) : (
                <div className="grid gap-4">
                    {claims.map((claim) => (
                        <ClaimCard key={claim.id} claim={claim} />
                    ))}
                </div>
            )}
        </>
    );
}
