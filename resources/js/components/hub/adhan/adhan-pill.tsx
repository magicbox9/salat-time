import { BellOff, Eye, Volume2, VolumeX } from 'lucide-react';
import { useT } from '@/lib/i18n';
import type { HubPrefs } from '../types';

const pill =
    'inline-flex items-center gap-1.5 rounded-full bg-white/12 px-3 py-1.5 text-xs font-medium text-white ring-1 ring-white/20 transition-colors hover:bg-white/20 focus-visible:ring-2 focus-visible:ring-gold focus-visible:outline-none';

/**
 * The adhan state in the hero. With sound on it mutes / unmutes in one tap
 * (in a mosque, or when the visitor prefers silence); otherwise it opens
 * the settings.
 */
export function AdhanPill({
    prefs,
    hasSound,
    onToggleMute,
    onOpenSettings,
}: {
    prefs: HubPrefs;
    hasSound: boolean;
    onToggleMute: () => void;
    onOpenSettings: () => void;
}) {
    const t = useT();

    if (prefs.adhan === 'sound' && hasSound) {
        return (
            <button
                type="button"
                className={pill}
                aria-pressed={prefs.muted}
                onClick={onToggleMute}
            >
                {prefs.muted ? (
                    <VolumeX className="size-3.5" aria-hidden />
                ) : (
                    <Volume2 className="size-3.5 text-gold" aria-hidden />
                )}
                {prefs.muted ? t('hub.adhan_muted') : t('hub.adhan_sound_on')}
            </button>
        );
    }

    return (
        <button type="button" className={pill} onClick={onOpenSettings}>
            {prefs.adhan === 'off' ? (
                <BellOff className="size-3.5" aria-hidden />
            ) : (
                <Eye className="size-3.5 text-gold" aria-hidden />
            )}
            {prefs.adhan === 'off'
                ? t('hub.adhan_is_off')
                : t('hub.adhan_visual_on')}
        </button>
    );
}
