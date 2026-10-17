import { router, usePage } from '@inertiajs/react';
import { useState } from 'react';
import { toast } from 'sonner';
import { useT } from '@/lib/i18n';
import { useSignInUrl } from '@/lib/sign-in';
import { RequestError, sendJson } from './api';
import type { FavoriteState, MosquePin } from './types';

/** The visitor's saved mosques on the globe, changed in place (guests sign in, then come back). */
export function useFavorites(initial: MosquePin[]) {
    const { auth } = usePage().props;
    const t = useT();
    const signIn = useSignInUrl();
    const [favorites, setFavorites] = useState<MosquePin[]>(initial);
    const [pending, setPending] = useState<number | null>(null);

    const isFavorite = (id: number) => favorites.some((f) => f.id === id);
    const isPrimary = (id: number) =>
        favorites.some((f) => f.id === id && f.is_primary);

    const change = async (
        pin: MosquePin,
        method: 'POST' | 'DELETE',
        path: 'favorite' | 'primary',
    ) => {
        if (!auth.user) {
            router.visit(signIn);

            return;
        }

        setPending(pin.id);

        try {
            const state = await sendJson<FavoriteState>(
                method,
                `/mosques/${encodeURIComponent(pin.slug)}/${path}`,
            );
            setFavorites((list) => apply(list, pin, state));
            toast.success(state.message);
        } catch (error) {
            // Signed out meanwhile (session expired, other tab): sign in again.
            if (error instanceof RequestError && error.status === 401) {
                router.visit(signIn);

                return;
            }

            toast.error(
                error instanceof RequestError && error.message
                    ? error.message
                    : t('site.error_generic'),
            );
        } finally {
            setPending(null);
        }
    };

    return {
        favorites,
        pending,
        isFavorite,
        isPrimary,
        primary: favorites.find((f) => f.is_primary) ?? null,
        toggleFavorite: (pin: MosquePin) =>
            change(pin, isFavorite(pin.id) ? 'DELETE' : 'POST', 'favorite'),
        togglePrimary: (pin: MosquePin) =>
            change(pin, isPrimary(pin.id) ? 'DELETE' : 'POST', 'primary'),
    };
}

/** The list after the server's answer: own mosque first, at most one of them. */
function apply(
    list: MosquePin[],
    pin: MosquePin,
    state: FavoriteState,
): MosquePin[] {
    let next = list.filter((f) => f.id !== pin.id);

    if (state.is_primary) {
        next = next.map((f) =>
            f.is_primary ? { ...f, is_primary: false } : f,
        );
    }

    if (!state.is_favorite) {
        return next;
    }

    const saved = { ...pin, is_primary: state.is_primary };

    return state.is_primary ? [saved, ...next] : [...next, saved];
}
