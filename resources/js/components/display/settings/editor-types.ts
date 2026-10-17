import type {
    AdhanTrack,
    DisplayOptions,
    DisplayPayload,
    DisplaySettings,
} from '../types';

/** What every settings section receives. */
export type EditorProps = {
    value: DisplaySettings;
    onChange: (patch: Partial<DisplaySettings>) => void;
    options: DisplayOptions;
    /** Validation messages by field ("blackout_minutes.fajr" …). */
    errors: Partial<Record<string, string>>;
    /** The mosque's data, for the live thumbnails (null before a mosque is chosen). */
    payload: DisplayPayload | null;
    catalog: AdhanTrack[];
    scope: 'mosque' | 'personal';
};
