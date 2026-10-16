import { router } from '@inertiajs/react';
import { toast } from 'sonner';
import type { Translate } from '@/lib/i18n';

/**
 * "Make it my mosque" (POST /my-mosque, guests too): the server answers
 * with "/" opening on its prayer times. A refusal (a full list of saved
 * mosques, a mosque that no longer exists) is told, never swallowed.
 */
export function chooseMosque(
    slug: string,
    t: Translate,
    busy: (pending: boolean) => void,
): void {
    router.post(
        '/my-mosque',
        { slug },
        {
            onStart: () => busy(true),
            onFinish: () => busy(false),
            onError: (errors) => {
                const first = Object.values(errors)[0];

                toast.error(
                    typeof first === 'string' && first
                        ? first
                        : t('site.error_generic'),
                );
            },
        },
    );
}
