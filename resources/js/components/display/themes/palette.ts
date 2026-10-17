import type { CSSProperties } from 'react';
import type { ThemeName } from '../types';

type Palette = {
    /** Solid backdrop of the full-screen moments (adhan, iqama …). */
    bg: string;
    fg: string;
    muted: string;
    panel: string;
    line: string;
    accent: string;
};

/** Salat Time's colours: deep green, gold, night sky (borrowed from the Mac app). */
export const PALETTES: Record<ThemeName, Palette> = {
    classic: {
        bg: '#062a22',
        fg: '#f6f1e4',
        muted: 'rgb(246 241 228 / 0.66)',
        panel: 'rgb(255 255 255 / 0.06)',
        line: 'rgb(255 255 255 / 0.12)',
        accent: '#d8b24a',
    },
    night_sky: {
        bg: '#0a1030',
        fg: '#f8fafc',
        muted: 'rgb(241 245 249 / 0.7)',
        panel: 'rgb(8 12 36 / 0.38)',
        line: 'rgb(255 255 255 / 0.16)',
        accent: '#f4c96b',
    },
    arabesque: {
        bg: '#05261c',
        fg: '#f7efd9',
        muted: 'rgb(247 239 217 / 0.68)',
        panel: 'rgb(201 162 39 / 0.07)',
        line: 'rgb(201 162 39 / 0.38)',
        accent: '#c9a227',
    },
    minimal: {
        bg: '#000000',
        fg: '#ffffff',
        muted: 'rgb(255 255 255 / 0.72)',
        panel: 'rgb(255 255 255 / 0.08)',
        line: 'rgb(255 255 255 / 0.22)',
        accent: '#f5c542',
    },
};

const HEX = /^#([0-9a-f]{6})$/i;

/** WCAG relative luminance of "#rrggbb" (null when it is not one). */
function luminance(hex: string): number | null {
    const match = HEX.exec(hex);

    if (!match) {
        return null;
    }

    const value = parseInt(match[1], 16);
    const channel = (shift: number) => {
        const c = ((value >> shift) & 255) / 255;

        return c <= 0.04045 ? c / 12.92 : ((c + 0.055) / 1.055) ** 2.4;
    };

    return 0.2126 * channel(16) + 0.7152 * channel(8) + 0.0722 * channel(0);
}

/** Black or white, whichever reads better on the accent colour. */
function inkOn(hex: string): string {
    return (luminance(hex) ?? 0) > 0.36 ? '#0b0f0d' : '#ffffff';
}

/**
 * The accent, lightened just enough to read on the theme's dark backdrop
 * (contrast 4.5:1): a deep colour chosen for a light page stays legible as
 * a lighter tint of itself.
 */
export function legibleAccent(color: string, background: string): string {
    const bg = luminance(background) ?? 0;

    if (!HEX.test(color)) {
        return color;
    }

    const value = parseInt(color.slice(1), 16);
    const rgb = [(value >> 16) & 255, (value >> 8) & 255, value & 255];

    for (let step = 0; step <= 20; step++) {
        const t = step * 0.05;
        const candidate = `#${rgb
            .map((c) =>
                Math.round(c + (255 - c) * t)
                    .toString(16)
                    .padStart(2, '0'),
            )
            .join('')}`;
        const l = luminance(candidate) ?? 1;

        if ((Math.max(l, bg) + 0.05) / (Math.min(l, bg) + 0.05) >= 4.5) {
            return candidate;
        }
    }

    return '#ffffff';
}

/** CSS variables every part of the screen reads (--d-accent, --d-fg …). */
export function stageVars(
    theme: ThemeName,
    accent: string | null,
): CSSProperties {
    const palette = PALETTES[theme];
    const color = legibleAccent(accent ?? palette.accent, palette.bg);

    return {
        '--d-bg': palette.bg,
        '--d-fg': palette.fg,
        '--d-muted': palette.muted,
        '--d-panel': palette.panel,
        '--d-line': palette.line,
        '--d-accent': color,
        '--d-accent-ink': inkOn(color),
        color: palette.fg,
    } as CSSProperties;
}
