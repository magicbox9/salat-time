import { BellRing, X } from 'lucide-react';
import { useState } from 'react';
import { Button } from '@/components/ui/button';
import { useT } from '@/lib/i18n';

/**
 * Browsers only let a page play sound after a tap. Shown once per visit when
 * the adhan sound is on: one tap and the adhan can play at its time.
 */
export function SoundPrompt({
    onEnable,
    onMute,
}: {
    onEnable: () => void;
    onMute: () => void;
}) {
    const t = useT();
    const [hidden, setHidden] = useState(false);

    if (hidden) {
        return null;
    }

    return (
        <div
            role="status"
            className="flex flex-wrap items-center gap-3 rounded-2xl border border-gold/40 bg-[color-mix(in_oklab,var(--gold)_8%,var(--card))] px-4 py-3 text-sm"
        >
            <BellRing className="size-4 shrink-0 text-gold" aria-hidden />
            <p className="min-w-0 flex-1">{t('hub.sound_prompt')}</p>
            <div className="flex items-center gap-2">
                <Button size="sm" onClick={onEnable}>
                    {t('hub.sound_enable')}
                </Button>
                <Button
                    size="sm"
                    variant="ghost"
                    onClick={() => {
                        onMute();
                        setHidden(true);
                    }}
                >
                    {t('hub.sound_mute')}
                </Button>
                <Button
                    size="icon"
                    variant="ghost"
                    className="size-8"
                    onClick={() => setHidden(true)}
                    aria-label={t('site.close')}
                >
                    <X className="size-4" />
                </Button>
            </div>
        </div>
    );
}
