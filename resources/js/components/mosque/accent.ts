import type { CSSProperties } from 'react';
import type { SiteAccent } from './site-types';

/**
 * The mosque's colour as CSS variables for its site. Without one, the
 * site uses the app's deep green. --site-accent-fg is the text colour the
 * server picked to read on the accent (WCAG contrast); --site-accent-ink-light
 * is the accent darkened, when needed, to read as text on the light theme.
 */
export function accentStyle(accent: SiteAccent): CSSProperties {
    return {
        '--site-accent': accent?.color ?? 'var(--primary)',
        '--site-accent-fg': accent?.foreground ?? 'var(--primary-foreground)',
        '--site-accent-ink-light': accent?.ink ?? 'var(--primary)',
    } as CSSProperties;
}

/** Relative luminance of a "#rrggbb" colour (WCAG 2.1). */
export function luminance(hex: string): number {
    const channels = [1, 3, 5].map((i) => {
        const c = parseInt(hex.slice(i, i + 2), 16) / 255;

        return c <= 0.03928 ? c / 12.92 : ((c + 0.055) / 1.055) ** 2.4;
    });

    return 0.2126 * channels[0] + 0.7152 * channels[1] + 0.0722 * channels[2];
}

export function contrastRatio(a: string, b: string): number {
    const [light, dark] = [luminance(a), luminance(b)].sort((x, y) => y - x);

    return (light + 0.05) / (dark + 0.05);
}

export const HEX_COLOR = /^#[0-9a-fA-F]{6}$/;
