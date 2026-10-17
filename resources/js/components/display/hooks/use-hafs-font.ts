import { useEffect, useState } from 'react';

/**
 * True once the KFGQPC Hafs face (declared by <QuranFonts />) is loaded:
 * only then is the verbatim corpus text, with its ayah-end glyphs, shown.
 * Until then (or offline without it) the verse is drawn without that glyph
 * and its number is drawn apart — the one rendering derivative allowed.
 */
export function useHafsFont(): boolean {
    const [ready, setReady] = useState(false);

    useEffect(() => {
        if (typeof document === 'undefined' || !document.fonts?.load) {
            return;
        }

        let cancelled = false;
        document.fonts
            .load("1em 'KFGQPC Hafs'")
            .then((faces) => {
                if (!cancelled) {
                    setReady(faces.length > 0);
                }
            })
            .catch(() => undefined);

        return () => {
            cancelled = true;
        };
    }, []);

    return ready;
}
