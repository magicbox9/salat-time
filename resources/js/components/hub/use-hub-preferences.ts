import { useEffect, useRef, useState } from 'react';
import { toast } from 'sonner';
import { sendJson } from '@/components/discover/api';
import { useT } from '@/lib/i18n';
import type { HubPrefs } from './types';
import { HUB_STYLES } from './types';

const STORAGE_KEY = 'salat-time.hub.preferences';

/** Waits for a burst of changes (toggling several switches) before saving. */
const SAVE_DELAY_MS = 500;

/** Keeps only known keys with valid values (localStorage is untrusted). */
export function cleanPrefs(value: unknown): Partial<HubPrefs> {
    if (!value || typeof value !== 'object') {
        return {};
    }

    const input = value as Record<string, unknown>;
    const out: Partial<HubPrefs> = {};
    const bool = (key: keyof HubPrefs) => {
        if (typeof input[key] === 'boolean') {
            (out as Record<string, unknown>)[key] = input[key];
        }
    };

    if (HUB_STYLES.includes(input.style as HubPrefs['style'])) {
        out.style = input.style as HubPrefs['style'];
    }

    if (input.clock === '24h' || input.clock === '12h') {
        out.clock = input.clock;
    }

    if (
        input.adhan === 'off' ||
        input.adhan === 'sound' ||
        input.adhan === 'visual'
    ) {
        out.adhan = input.adhan;
    }

    if (
        input.adhan_id === null ||
        (typeof input.adhan_id === 'string' &&
            /^[A-Za-z0-9_.:-]{1,128}$/.test(input.adhan_id))
    ) {
        out.adhan_id = input.adhan_id as string | null;
    }

    (
        [
            'show_iqama',
            'show_seconds',
            'show_hijri',
            'compact',
            'muted',
        ] as const
    ).forEach(bool);

    return out;
}

function readLocal(): Partial<HubPrefs> {
    try {
        const raw = window.localStorage.getItem(STORAGE_KEY);

        return raw ? cleanPrefs(JSON.parse(raw)) : {};
    } catch {
        return {};
    }
}

function writeLocal(prefs: HubPrefs): void {
    try {
        window.localStorage.setItem(STORAGE_KEY, JSON.stringify(prefs));
    } catch {
        // Private mode or storage full: the choice lasts for this visit.
    }
}

/**
 * The hub's display choices: on the account for signed-in users
 * (PATCH /me/preferences/home, only the changed keys), in this browser for
 * guests. Changes apply at once; saving happens in the background.
 */
export function useHubPreferences(server: HubPrefs | null, defaults: HubPrefs) {
    const t = useT();
    const signedIn = server !== null;
    const [prefs, setPrefs] = useState<HubPrefs>(() =>
        server
            ? { ...defaults, ...cleanPrefs(server) }
            : {
                  ...defaults,
                  ...(typeof window === 'undefined' ? {} : readLocal()),
              },
    );
    const pending = useRef<Partial<HubPrefs>>({});
    const timer = useRef<number | null>(null);

    useEffect(() => {
        if (!signedIn) {
            writeLocal(prefs);
        }
    }, [prefs, signedIn]);

    const flush = () => {
        const changes = pending.current;
        pending.current = {};
        timer.current = null;

        if (Object.keys(changes).length === 0) {
            return;
        }

        sendJson('PATCH', '/me/preferences/home', changes).catch(() => {
            toast.error(t('hub.prefs_failed'));
        });
    };

    // Leaving the page with unsaved changes: send them now.
    useEffect(
        () => () => {
            if (timer.current !== null) {
                window.clearTimeout(timer.current);
                flush();
            }
        },
        // eslint-disable-next-line react-hooks/exhaustive-deps
        [],
    );

    const update = (change: Partial<HubPrefs>) => {
        setPrefs((current) => ({ ...current, ...change }));

        if (!signedIn) {
            return;
        }

        pending.current = { ...pending.current, ...change };

        if (timer.current !== null) {
            window.clearTimeout(timer.current);
        }

        timer.current = window.setTimeout(flush, SAVE_DELAY_MS);
    };

    return {
        prefs,
        update,
        reset: () => update({ ...defaults }),
    };
}
