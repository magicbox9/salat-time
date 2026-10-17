import { router } from '@inertiajs/react';
import { Heart, Home, Share2 } from 'lucide-react';
import { useEffect, useState } from 'react';
import { toast } from 'sonner';
import { chooseMosque } from '@/components/discover/choose-mosque';
import { Button } from '@/components/ui/button';
import { useClipboard } from '@/hooks/use-clipboard';
import { useT } from '@/lib/i18n';
import { useSignInUrl } from '@/lib/sign-in';
import { cn } from '@/lib/utils';
import { api, errorMessage } from './api';
import type { MosqueDetails, MosqueViewer } from './types';

/** What the discover module answers to a JSON favourite request. */
type FavoriteAnswer = {
    is_favorite: boolean;
    is_primary: boolean;
    message?: string;
};

type Props = {
    mosque: MosqueDetails;
    viewer: MosqueViewer;
    shareUrl: string;
};

/**
 * Save the mosque, make it "my mosque", share the page. Saving needs an
 * account (a guest signs in and comes back here); "my mosque" works for
 * guests too, kept in a cookie like on the globe.
 */
export function MosqueActions({ mosque, viewer, shareUrl }: Props) {
    const t = useT();
    const signIn = useSignInUrl();
    const [, copy] = useClipboard();
    const [busy, setBusy] = useState(false);
    const [state, setState] = useState({
        favorite: viewer.favorite,
        primary: viewer.primary,
    });

    useEffect(() => {
        setState({ favorite: viewer.favorite, primary: viewer.primary });
    }, [viewer.favorite, viewer.primary]);

    // The favourite endpoints belong to the "discover" module: asked for JSON
    // they answer with the new state and a message (a redirect is not followed).
    const send = async (
        method: 'POST' | 'DELETE',
        path: 'favorite' | 'primary',
        next: typeof state,
    ) => {
        if (!viewer.signed_in) {
            router.visit(signIn);

            return;
        }

        const previous = state;
        setBusy(true);
        setState(next);

        try {
            const answer = await api<FavoriteAnswer | undefined>(
                method,
                `/mosques/${mosque.slug}/${path}`,
                undefined,
                { redirect: 'manual' },
            );

            if (answer && typeof answer.is_favorite === 'boolean') {
                setState({
                    favorite: answer.is_favorite,
                    primary: answer.is_primary,
                });
            }

            if (answer?.message) {
                toast.success(answer.message);
            }

            router.reload({ only: ['viewer'] });
        } catch (error) {
            setState(previous);
            toast.error(errorMessage(error, t));
        } finally {
            setBusy(false);
        }
    };

    const share = async () => {
        if (typeof navigator !== 'undefined' && navigator.share) {
            try {
                await navigator.share({ title: mosque.name, url: shareUrl });
            } catch {
                // Closing the share sheet is not an error.
            }

            return;
        }

        if (await copy(shareUrl)) {
            toast.success(t('mosque.link_copied'));
        } else {
            toast.error(t('site.error_generic'));
        }
    };

    return (
        <div className="flex flex-wrap items-center gap-2">
            <Button
                variant={state.favorite ? 'default' : 'outline'}
                disabled={busy}
                aria-pressed={state.favorite}
                onClick={() =>
                    send(state.favorite ? 'DELETE' : 'POST', 'favorite', {
                        favorite: !state.favorite,
                        primary: state.favorite ? false : state.primary,
                    })
                }
            >
                <Heart
                    className={cn('size-4', state.favorite && 'fill-current')}
                />
                {state.favorite ? t('mosque.saved') : t('mosque.save')}
            </Button>
            <Button
                variant="outline"
                disabled={busy}
                aria-pressed={state.primary}
                title={state.primary ? t('mosque.unset_my_mosque') : undefined}
                className={cn(state.primary && 'border-gold/60 bg-gold/10')}
                onClick={() => {
                    if (!viewer.signed_in) {
                        // Guests: the "my mosque" cookie; "/" then opens on its times.
                        if (state.primary) {
                            router.delete('/my-mosque');
                        } else {
                            chooseMosque(mosque.slug, t, setBusy);
                        }

                        return;
                    }

                    if (state.primary) {
                        void send('DELETE', 'primary', {
                            favorite: true,
                            primary: false,
                        });
                    } else {
                        void send('POST', 'primary', {
                            favorite: true,
                            primary: true,
                        });
                    }
                }}
            >
                <Home className={cn('size-4', state.primary && 'text-gold')} />
                {state.primary
                    ? t('mosque.is_my_mosque')
                    : t('mosque.make_my_mosque')}
            </Button>
            <Button
                variant="ghost"
                onClick={share}
                aria-label={t('mosque.share')}
            >
                <Share2 className="size-4" />
                <span className="hidden sm:inline">{t('mosque.share')}</span>
            </Button>
        </div>
    );
}
