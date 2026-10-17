import { router } from '@inertiajs/react';
import { useEffect } from 'react';

/**
 * Posts used to sit on the mosque's page as "#post-{id}" anchors. Those old
 * links now open the article (the server redirects to its address). When the
 * post is gone or not public, the visitor simply stays on the mosque's home:
 * the old anchor is dropped and no error dialog is shown.
 */
export function useLegacyPostAnchor(slug: string): void {
    useEffect(() => {
        const match = window.location.hash.match(/^#post-([1-9][0-9]{0,17})$/);

        if (!match || document.getElementById(`post-${match[1]}`)) {
            return;
        }

        router.visit(`/mosques/${slug}/posts/${match[1]}`, {
            replace: true,
            onHttpException: () => {
                window.history.replaceState(
                    window.history.state,
                    '',
                    `${window.location.pathname}${window.location.search}`,
                );

                return false;
            },
        });
    }, [slug]);
}
