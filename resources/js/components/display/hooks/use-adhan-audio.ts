import { useEffect, useRef, useState } from 'react';
import type { Phase } from '../lib/schedule';
import type { AdhanTrack, DisplaySettings } from '../types';

/**
 * A silent sound (20 ms of 8-bit PCM: an empty WAV is refused by some
 * browsers): playing it from a tap lets the page play the adhan later.
 */
const SILENCE = `data:audio/wav;base64,UklGRsQAAABXQVZFZm10IBAAAAABAAEAQB8AAEAfAAABAAgAZGF0YaAAAACA${'gICA'.repeat(53)}`;

/** The recording for an id, else the first one available. */
export function pickTrack(
    catalog: AdhanTrack[],
    id: string | null,
): AdhanTrack | null {
    return catalog.find((track) => track.id === id) ?? catalog[0] ?? null;
}

type Options = {
    phase: Phase;
    /** Minutes since the mosque's midnight. */
    nowMinutes: number;
    date: string;
    settings: DisplaySettings;
    catalog: AdhanTrack[];
    muted: boolean;
    /** False in the settings preview: it never makes a sound. */
    enabled: boolean;
};

/**
 * Plays the adhan recording when a prayer's adhan begins on screen (sound
 * mode, not muted, the page open at that moment). Browsers refuse sound
 * until the page has been touched: a silent clip is tried at start (a TV in
 * kiosk mode allows it) and the screen asks for one tap otherwise.
 */
export function useAdhanAudio({
    phase,
    nowMinutes,
    date,
    settings,
    catalog,
    muted,
    enabled,
}: Options) {
    const audio = useRef<HTMLAudioElement | null>(null);
    const played = useRef<string | null>(null);
    const [unlocked, setUnlocked] = useState(false);
    // The silent try has answered: only then is a refusal worth a prompt.
    const [probed, setProbed] = useState(false);
    const [playing, setPlaying] = useState(false);

    const main = settings.adhan_id
        ? pickTrack(catalog, settings.adhan_id)
        : (catalog[0] ?? null);
    // Fajr's own recording, else (unset or no longer offered) the main one.
    const fajr =
        catalog.find((track) => track.id === settings.fajr_adhan_id) ?? main;
    const soundOn = enabled && settings.adhan_mode === 'sound' && main !== null;
    const wants = soundOn && !muted;
    const event = phase.kind === 'adhan' ? phase.event : null;
    const key = event
        ? `${date}:${event.prayer}:${Math.round(event.adhan)}`
        : null;
    const fresh = event ? nowMinutes - event.adhan < 1 : false;
    const url = event?.prayer === 'fajr' ? fajr?.url : main?.url;

    const element = (): HTMLAudioElement => {
        if (!audio.current) {
            const created = new Audio();
            created.preload = 'auto';
            created.addEventListener('playing', () =>
                setPlaying(created.src !== SILENCE),
            );
            created.addEventListener('pause', () => setPlaying(false));
            created.addEventListener('ended', () => setPlaying(false));
            audio.current = created;
        }

        return audio.current;
    };

    const unlock = () => {
        if (playing) {
            return;
        }

        // A tap during the adhan starts the recording that was refused.
        const player = element();
        player.src = wants && event && url ? url : SILENCE;
        player.volume = Math.min(1, Math.max(0, settings.volume / 100));
        player
            .play()
            .then(() => setUnlocked(true))
            .catch((error: unknown) => {
                // Only a refusal of sound keeps the prompt: the tap itself has
                // been given, and a recording that fails to load is not the
                // browser asking for one.
                if (
                    !(error instanceof DOMException) ||
                    error.name !== 'NotAllowedError'
                ) {
                    setUnlocked(true);
                }
            });
    };

    // Is sound allowed without a tap here (kiosk flags, an earlier click)?
    useEffect(() => {
        if (!wants || unlocked) {
            return;
        }

        const player = element();
        player.src = SILENCE;
        player
            .play()
            .then(() => setUnlocked(true))
            .catch(() => undefined)
            .finally(() => setProbed(true));
    }, [wants]);

    // The adhan begins.
    useEffect(() => {
        if (!wants || !key || !url || !fresh || played.current === key) {
            return;
        }

        played.current = key;
        const player = element();
        player.src = url;
        player.currentTime = 0;
        player.volume = Math.min(1, Math.max(0, settings.volume / 100));
        player
            .play()
            .then(() => setUnlocked(true))
            .catch(() => {
                setUnlocked(false);
                setProbed(true);
            });
    }, [wants, key, url, fresh]);

    // Muted, or sound switched off: stop at once.
    useEffect(() => {
        if (!wants && audio.current && !audio.current.paused) {
            audio.current.pause();
        }
    }, [wants]);

    useEffect(() => {
        if (audio.current) {
            audio.current.volume = Math.min(
                1,
                Math.max(0, settings.volume / 100),
            );
        }
    }, [settings.volume]);

    useEffect(() => () => audio.current?.pause(), []);

    return {
        needsUnlock: wants && !unlocked && probed,
        unlock,
        playing,
        soundOn,
    };
}
