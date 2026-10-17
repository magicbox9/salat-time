import { Volume2 } from 'lucide-react';
import { useEffect, useState } from 'react';
import { useT } from '@/lib/i18n';

/** After this long without a tap the prompt shrinks to a corner, so an unattended TV shows its times. */
const SHRINK_AFTER_MS = 45_000;

/**
 * Browsers only play sound after the page has been touched: a one-time
 * invitation to tap, shown when the adhan is set to sound.
 */
export function SoundPrompt({ onUnlock }: { onUnlock: () => void }) {
    const t = useT();
    const [small, setSmall] = useState(false);

    useEffect(() => {
        const timer = window.setTimeout(() => setSmall(true), SHRINK_AFTER_MS);

        return () => window.clearTimeout(timer);
    }, []);

    if (small) {
        return (
            <button
                type="button"
                onClick={onUnlock}
                className="absolute start-3 top-3 z-50 flex items-center gap-2 rounded-full bg-black/60 px-3.5 py-1.5 text-sm text-white ring-1 ring-white/20 backdrop-blur focus-visible:outline-2 focus-visible:outline-white"
            >
                <Volume2 className="size-4" aria-hidden />
                {t('display.sound_prompt_short')}
            </button>
        );
    }

    return (
        <button
            type="button"
            onClick={onUnlock}
            className="absolute inset-0 z-50 flex cursor-pointer items-center justify-center bg-black/55 p-6 backdrop-blur-sm focus-visible:outline-none"
            aria-label={t('display.sound_prompt_action')}
        >
            <span className="d-fade-up flex max-w-md flex-col items-center gap-4 rounded-3xl bg-[#062a22]/95 px-8 py-8 text-center text-white shadow-2xl ring-1 ring-[var(--gold)]/40">
                <span className="flex size-16 items-center justify-center rounded-full bg-[var(--gold)]/15 text-[var(--gold)] ring-1 ring-[var(--gold)]/40">
                    <Volume2 className="size-8" aria-hidden />
                </span>
                <span className="text-xl font-semibold">
                    {t('display.sound_prompt_title')}
                </span>
                <span className="text-sm leading-relaxed text-white/75">
                    {t('display.sound_prompt_body')}
                </span>
                <span className="mt-2 rounded-full bg-[var(--gold)] px-6 py-2.5 text-sm font-semibold text-[#062a22]">
                    {t('display.sound_prompt_action')}
                </span>
            </span>
        </button>
    );
}
