import { useEffect, useState } from 'react';
import { writeStored } from './types';
import type { Ayah } from './types';
import type { RecitationState } from './use-recitation';

export function scrollToAyah(ayah: number, smooth = true): boolean {
    const element = document.getElementById(`ayah-${ayah}`);
    element?.scrollIntoView({
        behavior: smooth ? 'smooth' : 'auto',
        block: 'center',
    });

    return element !== null;
}

/**
 * Where the reader is: arriving at #ayah-N, "go to ayah", following the
 * recitation, and remembering the position for "pick up where you left off".
 */
export function useReaderNavigation(
    surah: number,
    ayat: Ayah[],
    recitation: RecitationState,
) {
    const [highlight, setHighlight] = useState<number | null>(null);
    const following = recitation.status !== 'idle' && !recitation.basmala;

    // Arriving with #ayah-N (bookmarks, "continue reading").
    useEffect(() => {
        const match = /^#ayah-(\d+)$/.exec(window.location.hash);
        if (!match) {
            return;
        }
        const ayah = Number(match[1]);
        if (scrollToAyah(ayah, false)) {
            setHighlight(ayah);
            // The Qur'an font changes line heights once loaded: settle again.
            void document.fonts?.ready.then(() => scrollToAyah(ayah, false));
        }
    }, [surah]);

    useEffect(() => {
        if (highlight === null) {
            return;
        }
        const timer = window.setTimeout(() => setHighlight(null), 2500);

        return () => window.clearTimeout(timer);
    }, [highlight]);

    // Follow the recitation when the ayah being recited is out of view.
    useEffect(() => {
        if (!following || recitation.ayah === null) {
            return;
        }
        const element = document.getElementById(`ayah-${recitation.ayah}`);
        const rect = element?.getBoundingClientRect();
        if (
            element &&
            rect &&
            (rect.top < 120 || rect.bottom > window.innerHeight - 120)
        ) {
            element.scrollIntoView({ behavior: 'smooth', block: 'center' });
        }
    }, [following, recitation.ayah]);

    // Remember the ayah in the middle of the screen.
    useEffect(() => {
        const observer = new IntersectionObserver(
            (entries) => {
                const visible = entries.find((entry) => entry.isIntersecting);
                const ayah = Number(visible?.target.id.replace('ayah-', ''));
                if (ayah > 0) {
                    writeStored('quran:last', JSON.stringify({ surah, ayah }));
                }
            },
            { rootMargin: '-45% 0px -50% 0px' },
        );
        document
            .querySelectorAll('article[id^="ayah-"]')
            .forEach((element) => observer.observe(element));

        return () => observer.disconnect();
    }, [surah, ayat]);

    return {
        highlight,
        goTo: (ayah: number) => {
            if (scrollToAyah(ayah)) {
                setHighlight(ayah);
            }
        },
    };
}
