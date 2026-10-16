import { useEffect, useRef, useState } from 'react';
import { readStored, writeStored } from './types';
import type { Reciter } from './types';

export type RecitationStatus =
    | 'idle'
    | 'loading'
    | 'playing'
    | 'paused'
    | 'error';

export type RecitationState = {
    status: RecitationStatus;
    /** The ayah being recited (the basmala plays before ayah 1). */
    ayah: number | null;
    basmala: boolean;
};

const IDLE: RecitationState = { status: 'idle', ayah: null, basmala: false };
const RECITER_KEY = 'quran:reciter';

/** EveryAyah.com verse-by-verse file (Hafs numbering): SSSAAA.mp3. */
export function everyAyahUrl(
    reciter: string,
    surah: number,
    ayah: number,
): string {
    const pad = (n: number) => String(n).padStart(3, '0');

    return `https://everyayah.com/data/${encodeURIComponent(reciter)}/${pad(surah)}${pad(ayah)}.mp3`;
}

type Options = {
    surah: number;
    ayahCount: number;
    reciters: Reciter[];
};

/**
 * Continuous recitation from a chosen ayah. Nothing is requested before the
 * visitor presses play; after that the next ayah is fetched one step ahead
 * so playback flows without gaps. Surahs other than Al-Fātiḥah and At-Tawbah
 * open with the basmala (EveryAyah 001001), as in the Mac app.
 */
export function useRecitation({ surah, ayahCount, reciters }: Options) {
    const [state, setState] = useState<RecitationState>(IDLE);
    const [reciter, setReciterState] = useState(() => {
        const stored = readStored(RECITER_KEY);

        return reciters.some((r) => r.id === stored)
            ? (stored as string)
            : reciters[0].id;
    });
    const audioRef = useRef<HTMLAudioElement | null>(null);
    const nextRef = useRef<HTMLAudioElement | null>(null);
    const positionRef = useRef({ ayah: 0, basmala: false });
    const settingsRef = useRef({ surah, ayahCount, reciter });

    useEffect(() => {
        settingsRef.current = { ...settingsRef.current, surah, ayahCount };
    }, [surah, ayahCount]);

    const start = (ayah: number, basmala: boolean) => {
        const { surah: s, ayahCount: count, reciter: r } = settingsRef.current;
        const audio = audioRef.current ?? createPlayer();
        positionRef.current = { ayah, basmala };
        setState({ status: 'loading', ayah, basmala });
        audio.src = basmala ? everyAyahUrl(r, 1, 1) : everyAyahUrl(r, s, ayah);
        audio.play().catch((error: unknown) => {
            // The browser refused to go on by itself (e.g. a locked phone):
            // wait for the visitor instead of spinning forever. Other
            // rejections mean a newer start(); failures arrive as "error".
            if (
                error instanceof DOMException &&
                error.name === 'NotAllowedError'
            ) {
                setState((c) => ({ ...c, status: 'paused' }));
            }
        });

        const upcoming = basmala ? ayah : ayah + 1;
        if (upcoming <= count) {
            const next = nextRef.current ?? (nextRef.current = new Audio());
            next.preload = 'auto';
            next.src = everyAyahUrl(r, s, upcoming);
        }
    };

    function createPlayer(): HTMLAudioElement {
        const audio = new Audio();
        audio.preload = 'auto';
        audio.addEventListener('playing', () =>
            setState((c) => ({ ...c, status: 'playing' })),
        );
        audio.addEventListener('waiting', () =>
            setState((c) => ({ ...c, status: 'loading' })),
        );
        audio.addEventListener('pause', () =>
            setState((c) =>
                (c.status === 'playing' || c.status === 'loading') &&
                !audio.ended
                    ? { ...c, status: 'paused' }
                    : c,
            ),
        );
        audio.addEventListener('error', () => {
            if (audio.getAttribute('src')) {
                setState((c) => ({ ...c, status: 'error' }));
            }
        });
        audio.addEventListener('ended', () => {
            const { ayah, basmala } = positionRef.current;
            if (basmala) {
                start(ayah, false);
            } else if (ayah < settingsRef.current.ayahCount) {
                start(ayah + 1, false);
            } else {
                silence();
                setState(IDLE);
            }
        });
        audioRef.current = audio;

        return audio;
    }

    function silence() {
        for (const audio of [audioRef.current, nextRef.current]) {
            if (audio) {
                audio.pause();
                audio.removeAttribute('src');
            }
        }
    }

    const play = (fromAyah: number) => {
        const s = settingsRef.current.surah;
        start(fromAyah, fromAyah === 1 && s !== 1 && s !== 9);
    };

    const step = (delta: number) => {
        const { ayah, basmala } = positionRef.current;
        // During the basmala, "next" moves on to the ayah it introduces.
        const target = basmala && delta > 0 ? ayah : ayah + delta;
        if (target >= 1 && target <= settingsRef.current.ayahCount) {
            start(target, false);
        }
    };

    const setReciter = (id: string) => {
        if (!reciters.some((r) => r.id === id)) {
            return;
        }
        writeStored(RECITER_KEY, id);
        setReciterState(id);
        settingsRef.current = { ...settingsRef.current, reciter: id };
        // The new voice takes over from the current ayah.
        const audio = audioRef.current;
        if (audio && !audio.paused && positionRef.current.ayah > 0) {
            start(positionRef.current.ayah, positionRef.current.basmala);
        }
    };

    // Moving to another surah (or leaving the page) silences everything.
    useEffect(
        () => () => {
            silence();
            positionRef.current = { ayah: 0, basmala: false };
            setState(IDLE);
        },
        [surah],
    );

    return {
        state,
        reciter,
        setReciter,
        play,
        pause: () => {
            audioRef.current?.pause();
            setState((c) =>
                c.status === 'idle' || c.status === 'error'
                    ? c
                    : { ...c, status: 'paused' },
            );
        },
        resume: () => {
            const audio = audioRef.current;
            if (!audio) {
                return;
            }
            setState((c) => ({ ...c, status: 'loading' }));
            audio.play().catch((error: unknown) => {
                // A pause during loading aborts play(); that is not a failure.
                if (
                    !(
                        error instanceof DOMException &&
                        error.name === 'AbortError'
                    )
                ) {
                    setState((c) => ({ ...c, status: 'error' }));
                }
            });
        },
        stop: () => {
            silence();
            setState(IDLE);
        },
        next: () => step(1),
        previous: () => step(-1),
    };
}
