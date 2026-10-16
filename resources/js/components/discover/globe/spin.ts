import type { Map as MapLibreMap } from 'maplibre-gl';
import { SPIN_MAX_ZOOM } from './map-style';

export type Spin = {
    /** Stops for good (a place was chosen). */
    stop: () => void;
    isOn: () => boolean;
};

/** One full turn of the globe, in seconds. */
const SECONDS_PER_TURN = 150;

/**
 * Turns the globe slowly westward, one second-long linear ease at a time.
 * It pauses while the visitor drags, zooms or touches the globe, carries on
 * afterwards, and never runs when the visitor prefers reduced motion.
 */
export function startSpin(map: MapLibreMap, reducedMotion: boolean): Spin {
    let enabled = !reducedMotion;
    let interacting = false;
    let resumeTimer = 0;

    const step = () => {
        if (!enabled || interacting || map.getZoom() > SPIN_MAX_ZOOM) {
            return;
        }

        const center = map.getCenter();
        center.lng -= 360 / SECONDS_PER_TURN;
        map.easeTo({
            center,
            duration: 1000,
            easing: (n) => n,
            essential: false,
        });
    };

    const pause = () => {
        interacting = true;
        window.clearTimeout(resumeTimer);
    };

    const resume = () => {
        window.clearTimeout(resumeTimer);
        resumeTimer = window.setTimeout(() => {
            interacting = false;
            step();
        }, 1500);
    };

    const onMoveEnd = (event: { originalEvent?: unknown }) => {
        // Moves started by the visitor resume through `resume`.
        if (!event.originalEvent && !interacting) {
            step();
        }
    };

    map.on('mousedown', pause);
    map.on('touchstart', pause);
    map.on('wheel', pause);
    map.on('mouseup', resume);
    map.on('touchend', resume);
    map.on('wheel', resume);
    map.on('dragend', resume);
    map.on('moveend', onMoveEnd);

    if (map.loaded()) {
        step();
    } else {
        void map.once('load', step);
    }

    return {
        stop: () => {
            enabled = false;
            window.clearTimeout(resumeTimer);
            map.off('mousedown', pause);
            map.off('touchstart', pause);
            map.off('wheel', pause);
            map.off('mouseup', resume);
            map.off('touchend', resume);
            map.off('wheel', resume);
            map.off('dragend', resume);
            map.off('moveend', onMoveEnd);
        },
        isOn: () => enabled,
    };
}
