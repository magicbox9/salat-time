import { useEffect, useRef, useState } from 'react';
import type { PrayerName } from '@/types/mosque';
import type { AdhanTrack, DayView, HubPrefs } from '../types';

/** How long the visual adhan stays up after the adhan time (unless the sound still plays). */
const SHOW_MINUTES = 5;

/** A silent sound: playing it from a tap lets the page play the adhan later. */
const SILENCE =
    'data:audio/wav;base64,UklGRiQAAABXQVZFZm10IBAAAAABAAEARKwAAIhYAQACABAAZGF0YQAAAAA=';

export type AdhanMoment = { key: string; prayer: PrayerName; time: string };

/**
 * The adhan inside the open page. At a prayer's adhan time (only when the
 * page was already open, or within its first minute) it plays the chosen
 * recording when sound is on and not muted, and shows the visual adhan.
 * Browsers refuse sound before the visitor has touched the page: the first
 * tap or key press unlocks it, and a one-time prompt offers to do so.
 */
export function useAdhan({
    view,
    prefs,
    track,
    now,
}: {
    view: DayView | null;
    prefs: HubPrefs;
    track: AdhanTrack | null;
    now: Date;
}) {
    const audio = useRef<HTMLAudioElement | null>(null);
    const started = useRef<string | null>(null);
    const [openedAt] = useState(() => Date.now());
    const [dismissed, setDismissed] = useState<string | null>(null);
    const [playing, setPlaying] = useState(false);
    // The adhan whose recording this page started (not a preview): its
    // visual stays up while it plays, past SHOW_MINUTES.
    const [sounding, setSounding] = useState<AdhanMoment | null>(null);
    const [blocked, setBlocked] = useState(false);
    // A visitor who already clicked in this tab (e.g. a link to this page) may hear sound.
    const [unlocked, setUnlocked] = useState(
        () =>
            typeof navigator !== 'undefined' &&
            (
                navigator as Navigator & {
                    userActivation?: { hasBeenActive: boolean };
                }
            ).userActivation?.hasBeenActive === true,
    );

    const minutesOpen = (now.getTime() - openedAt) / 60_000;
    let due: AdhanMoment | null = null;

    if (view && prefs.adhan !== 'off') {
        for (const row of view.rows) {
            const since = view.nowMinutes - row.minutes;

            if (
                row.prayer !== 'shuruq' &&
                !row.tomorrow &&
                since >= 0 &&
                since < SHOW_MINUTES &&
                since <= minutesOpen + 1
            ) {
                due = {
                    key: `${view.today.date}:${row.prayer}`,
                    prayer: row.prayer,
                    time: row.time,
                };
            }
        }
    }

    const element = (): HTMLAudioElement => {
        if (!audio.current) {
            const created = new Audio();
            created.preload = 'none';
            created.addEventListener('playing', () => setPlaying(true));
            created.addEventListener('pause', () => setPlaying(false));
            created.addEventListener('ended', () => setPlaying(false));
            audio.current = created;
        }

        return audio.current;
    };

    const play = (url: string) => {
        const player = element();
        player.muted = false;
        player.src = url;
        player.currentTime = 0;

        return player
            .play()
            .then(() => {
                setBlocked(false);
                setUnlocked(true);
            })
            .catch((error: unknown) => {
                if (
                    error instanceof DOMException &&
                    error.name === 'NotAllowedError'
                ) {
                    setBlocked(true);
                }
            });
    };

    const stop = () => {
        const player = audio.current;

        if (player) {
            player.pause();
            player.currentTime = 0;
        }
    };

    const unlock = () => {
        const player = element();
        player.muted = true;
        player.src = SILENCE;
        player
            .play()
            .then(() => {
                player.pause();
                setUnlocked(true);
            })
            .catch(() => undefined)
            .finally(() => {
                player.muted = false;
            });
    };

    const wantsSound =
        prefs.adhan === 'sound' && !prefs.muted && track !== null;
    const dueKey = due?.key ?? null;
    // The official adhan has its own Fajr version.
    const trackUrl =
        (due?.prayer === 'fajr' ? track?.fajr_url : undefined) ??
        track?.url ??
        null;

    // The adhan time has come: play once per prayer and day.
    useEffect(() => {
        if (!dueKey || !wantsSound || !trackUrl || started.current === dueKey) {
            return;
        }

        started.current = dueKey;
        setSounding(due);
        void play(trackUrl);
        // eslint-disable-next-line react-hooks/exhaustive-deps
    }, [dueKey, wantsSound, trackUrl]);

    // Muted or switched off while playing: stop at once.
    useEffect(() => {
        if (!wantsSound) {
            stop();
        }
    }, [wantsSound]);

    // The first tap or key press anywhere allows the sound later on.
    useEffect(() => {
        if (!wantsSound || unlocked) {
            return;
        }

        const onGesture = () => unlock();
        document.addEventListener('pointerdown', onGesture, { once: true });
        document.addEventListener('keydown', onGesture, { once: true });

        return () => {
            document.removeEventListener('pointerdown', onGesture);
            document.removeEventListener('keydown', onGesture);
        };
        // eslint-disable-next-line react-hooks/exhaustive-deps
    }, [wantsSound, unlocked]);

    useEffect(() => () => audio.current?.pause(), []);

    const shown = due ?? (playing && sounding !== null ? sounding : null);

    return {
        moment: shown !== null && dismissed !== shown.key ? shown : null,
        playing,
        /** The browser refused to start the sound by itself. */
        blocked: blocked && wantsSound,
        /** Show the one-time "enable sound" prompt. */
        needsUnlock: wantsSound && !unlocked,
        unlock,
        stop,
        playNow: () => (trackUrl ? void play(trackUrl) : undefined),
        preview: (url: string) => {
            setSounding(null);
            void play(url);
        },
        dismiss: () => {
            stop();
            setDismissed(shown?.key ?? null);
        },
    };
}
