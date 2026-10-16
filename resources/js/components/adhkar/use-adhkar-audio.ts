import { useEffect, useRef, useState } from 'react';

export type AdhkarAudioState = {
    id: string | null;
    status: 'idle' | 'loading' | 'playing' | 'error';
};

const IDLE: AdhkarAudioState = { id: null, status: 'idle' };

/**
 * One shared player for a category page. The recording is requested from
 * its publisher only when the visitor presses Listen.
 */
export function useAdhkarAudio() {
    const [state, setState] = useState<AdhkarAudioState>(IDLE);
    const audioRef = useRef<HTMLAudioElement | null>(null);

    function player(): HTMLAudioElement {
        if (audioRef.current) {
            return audioRef.current;
        }
        const audio = new Audio();
        audio.preload = 'none';
        audio.addEventListener('playing', () =>
            setState((s) => ({ ...s, status: 'playing' })),
        );
        audio.addEventListener('waiting', () =>
            setState((s) => ({ ...s, status: 'loading' })),
        );
        audio.addEventListener('ended', () => setState(IDLE));
        audio.addEventListener('pause', () =>
            setState((s) => (s.status === 'playing' ? IDLE : s)),
        );
        audio.addEventListener('error', () => {
            if (audio.getAttribute('src')) {
                setState((s) => ({ ...s, status: 'error' }));
            }
        });
        audioRef.current = audio;

        return audio;
    }

    const toggle = (id: string, url: string) => {
        const audio = player();
        if (
            state.id === id &&
            (state.status === 'playing' || state.status === 'loading')
        ) {
            audio.pause();
            setState(IDLE);

            return;
        }
        setState({ id, status: 'loading' });
        audio.src = url;
        audio.play().catch(() => {
            // Replaced by another recording; real failures arrive as "error".
        });
    };

    useEffect(
        () => () => {
            const audio = audioRef.current;
            if (audio) {
                audio.pause();
                audio.removeAttribute('src');
            }
        },
        [],
    );

    return { state, toggle };
}
