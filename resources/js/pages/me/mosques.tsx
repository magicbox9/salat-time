import { Head, Link, router } from '@inertiajs/react';
import { Globe2, Heart } from 'lucide-react';
import { useState } from 'react';
import { SavedMosqueCard } from '@/components/discover/saved-mosque-card';
import type { MosqueCard } from '@/components/discover/types';
import { Button } from '@/components/ui/button';
import { useT } from '@/lib/i18n';

/** /me/mosques — the mosques the visitor saved, their own mosque first. */
export default function MyMosques({ mosques }: { mosques: MosqueCard[] }) {
    const t = useT();
    const [busy, setBusy] = useState<string | null>(null);

    const send = (
        method: 'post' | 'delete',
        mosque: MosqueCard,
        path: 'favorite' | 'primary',
    ) => {
        router.visit(`/mosques/${encodeURIComponent(mosque.slug)}/${path}`, {
            method,
            preserveScroll: true,
            onStart: () => setBusy(mosque.slug),
            onFinish: () => setBusy(null),
        });
    };

    return (
        <>
            <Head title={t('discover.mine_title')} />

            <header className="mb-8 flex flex-wrap items-end justify-between gap-4">
                <div>
                    <h1 className="text-2xl font-semibold tracking-tight">
                        {t('discover.mine_title')}
                    </h1>
                    <p className="mt-1 max-w-2xl text-muted-foreground">
                        {t('discover.mine_intro')}
                    </p>
                </div>
                {mosques.length > 0 && (
                    <Button asChild variant="outline">
                        <Link href="/">
                            <Globe2 />
                            {t('discover.find_more')}
                        </Link>
                    </Button>
                )}
            </header>

            {mosques.length === 0 ? (
                <div className="flex flex-col items-center rounded-xl border border-dashed px-6 py-16 text-center">
                    <span className="flex size-12 items-center justify-center rounded-full bg-gold/15 text-gold">
                        <Heart className="size-6" aria-hidden />
                    </span>
                    <h2 className="mt-4 text-lg font-semibold">
                        {t('discover.mine_empty_title')}
                    </h2>
                    <p className="mt-1 max-w-md text-sm text-muted-foreground">
                        {t('discover.mine_empty_text')}
                    </p>
                    <Button asChild className="mt-6">
                        <Link href="/">
                            <Globe2 />
                            {t('discover.mine_empty_action')}
                        </Link>
                    </Button>
                </div>
            ) : (
                <div className="grid gap-4 md:grid-cols-2">
                    {mosques.map((mosque) => (
                        <SavedMosqueCard
                            key={mosque.id}
                            mosque={mosque}
                            busy={busy === mosque.slug}
                            onTogglePrimary={() =>
                                send(
                                    mosque.is_primary ? 'delete' : 'post',
                                    mosque,
                                    'primary',
                                )
                            }
                            onRemove={() => send('delete', mosque, 'favorite')}
                        />
                    ))}
                </div>
            )}
        </>
    );
}
