import { useEffect, useState } from 'react';

const key = (slug: string) => `salat-time:display-muted:${slug}`;

/** The key the personal screen at /display uses. */
export const PERSONAL_MUTE_SLUG = 'personal';

/**
 * The on-screen mute switch, remembered by this device for this screen.
 * Until it is used here, the screen follows `fallback` (a person's saved
 * "mute" choice, which for guests only arrives after the first render).
 */
export function useDeviceMute(
    slug: string | null,
    fallback: boolean,
): [boolean, (muted: boolean) => void] {
    const [stored, setStored] = useState<boolean | null>(null);

    // Read after mounting (the server render knows nothing of this device).
    useEffect(() => {
        if (!slug) {
            return;
        }

        try {
            const value = window.localStorage.getItem(key(slug));
            setStored(value === null ? null : value === '1');
        } catch {
            // Storage unavailable: follow the setting.
        }
    }, [slug]);

    const update = (value: boolean) => {
        setStored(value);

        if (slug) {
            try {
                window.localStorage.setItem(key(slug), value ? '1' : '0');
            } catch {
                // Storage unavailable: the switch still works for this visit.
            }
        }
    };

    return [stored ?? fallback, update];
}

/** Forgets this device's switch, so the screen follows the saved setting again. */
export function clearDeviceMute(slug: string): void {
    try {
        window.localStorage.removeItem(key(slug));
    } catch {
        // Nothing stored, or storage unavailable.
    }
}
