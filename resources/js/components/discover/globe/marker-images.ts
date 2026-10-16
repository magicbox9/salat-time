import type { Map as MapLibreMap } from 'maplibre-gl';
import type { MapTheme } from './map-style';
import { PALETTE } from './map-style';

export const STAR_IMAGE = 'discover-star';
export const PRIMARY_IMAGE = 'discover-primary';

const RATIO = 2;

function canvas(size: number): CanvasRenderingContext2D | null {
    const element = document.createElement('canvas');
    element.width = size * RATIO;
    element.height = size * RATIO;
    const context = element.getContext('2d');
    context?.scale(RATIO, RATIO);

    return context;
}

function starPath(
    context: CanvasRenderingContext2D,
    cx: number,
    cy: number,
    outer: number,
    inner: number,
): void {
    context.beginPath();

    for (let i = 0; i < 10; i++) {
        const radius = i % 2 === 0 ? outer : inner;
        const angle = (Math.PI / 5) * i - Math.PI / 2;
        const x = cx + radius * Math.cos(angle);
        const y = cy + radius * Math.sin(angle);

        if (i === 0) {
            context.moveTo(x, y);
        } else {
            context.lineTo(x, y);
        }
    }

    context.closePath();
}

/** A gold star: a saved mosque. */
function star(theme: MapTheme): ImageData | null {
    const size = 28;
    const context = canvas(size);

    if (!context) {
        return null;
    }

    const colors = PALETTE[theme];
    starPath(context, size / 2, size / 2 + 0.8, 12.5, 5.6);
    context.fillStyle = colors.gold;
    context.strokeStyle = colors.ring;
    context.lineWidth = 2;
    context.lineJoin = 'round';
    context.fill();
    context.stroke();

    return context.getImageData(0, 0, size * RATIO, size * RATIO);
}

/** The visitor's own mosque: a green medallion with a gold ring and a crescent. */
function primary(theme: MapTheme): ImageData | null {
    const size = 30;
    const context = canvas(size);

    if (!context) {
        return null;
    }

    const colors = PALETTE[theme];
    const c = size / 2;
    context.beginPath();
    context.arc(c, c, 13, 0, Math.PI * 2);
    context.fillStyle = colors.gold;
    context.fill();
    context.beginPath();
    const medallion = theme === 'dark' ? '#14513f' : '#0f6b56';
    context.arc(c, c, 10.5, 0, Math.PI * 2);
    context.fillStyle = medallion;
    context.fill();

    // Crescent: a white disc covered by an offset disc of the medallion's
    // green (painted over, not cut out: cutting would punch a see-through
    // hole in the medallion, as the offset disc reaches past the white one).
    context.beginPath();
    context.arc(c - 0.5, c, 6, 0, Math.PI * 2);
    context.fillStyle = '#ffffff';
    context.fill();
    context.beginPath();
    context.arc(c + 2, c - 1.2, 5, 0, Math.PI * 2);
    context.fillStyle = medallion;
    context.fill();
    starPath(context, c + 3.6, c + 1.4, 2.2, 0.95);
    context.fillStyle = '#ffffff';
    context.fill();

    return context.getImageData(0, 0, size * RATIO, size * RATIO);
}

/** (Re)draws the icons for the current theme; called after every style load. */
export function installImages(map: MapLibreMap, theme: MapTheme): void {
    for (const [id, image] of [
        [STAR_IMAGE, star(theme)],
        [PRIMARY_IMAGE, primary(theme)],
    ] as const) {
        if (!image) {
            continue;
        }

        if (map.hasImage(id)) {
            map.removeImage(id);
        }

        map.addImage(id, image, { pixelRatio: RATIO });
    }
}
