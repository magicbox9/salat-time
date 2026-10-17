import { Check } from 'lucide-react';
import { useEffect, useState } from 'react';
import { useT } from '@/lib/i18n';
import { cn } from '@/lib/utils';
import { DisplayScreen } from '../screen/display-screen';
import { PALETTES } from '../themes/palette';
import type { DisplayPayload, DisplaySettings, ThemeName } from '../types';
import { THEMES } from '../types';
import type { EditorProps } from './editor-types';

/** The four themes, each shown live on the mosque's own data when there is some. */
export function ThemePicker({
    value,
    onChange,
    payload,
}: Pick<EditorProps, 'value' | 'onChange' | 'payload'>) {
    const t = useT();
    const now = useMinute();

    return (
        <div className="grid gap-2">
            <span className="text-sm font-medium">{t('display.theme')}</span>
            <div
                role="radiogroup"
                aria-label={t('display.theme')}
                className="grid grid-cols-2 gap-3"
            >
                {THEMES.map((theme) => (
                    <button
                        key={theme}
                        type="button"
                        role="radio"
                        aria-checked={value.theme === theme}
                        onClick={() => onChange({ theme })}
                        className={cn(
                            'group relative flex flex-col overflow-hidden rounded-xl border text-start transition-shadow focus-visible:ring-[3px] focus-visible:ring-ring/50 focus-visible:outline-none',
                            value.theme === theme
                                ? 'border-primary ring-2 ring-primary/40'
                                : 'hover:border-foreground/30',
                        )}
                    >
                        <Thumbnail
                            theme={theme}
                            value={value}
                            payload={payload}
                            now={now}
                        />
                        <span className="flex items-center justify-between gap-2 px-3 py-2">
                            <span className="min-w-0">
                                <span className="block text-sm font-medium">
                                    {t(`display.theme_${theme}`)}
                                </span>
                                <span className="block truncate text-xs text-muted-foreground">
                                    {t(`display.theme_${theme}_hint`)}
                                </span>
                            </span>
                            {value.theme === theme && (
                                <Check
                                    className="size-4 shrink-0 text-primary"
                                    aria-hidden
                                />
                            )}
                        </span>
                    </button>
                ))}
            </div>
        </div>
    );
}

function Thumbnail({
    theme,
    value,
    payload,
    now,
}: {
    theme: ThemeName;
    value: DisplaySettings;
    payload: DisplayPayload | null;
    now: Date;
}) {
    if (!payload) {
        const palette = PALETTES[theme];

        // No mosque yet: a sketch of the theme in its own colours.
        return (
            <span
                className="flex aspect-video flex-col items-center justify-center gap-2"
                style={{ background: palette.bg, color: palette.fg }}
                aria-hidden
            >
                <span className="text-2xl font-semibold tracking-tight tabular-nums">
                    12:30
                </span>
                <span className="flex gap-1">
                    {[0, 1, 2, 3, 4].map((i) => (
                        <span
                            key={i}
                            className="h-1.5 w-5 rounded-full"
                            style={{
                                background:
                                    i === 2 ? palette.accent : palette.line,
                            }}
                        />
                    ))}
                </span>
            </span>
        );
    }

    return (
        <span
            className="pointer-events-none block aspect-video"
            aria-hidden
            inert
        >
            <DisplayScreen
                payload={payload}
                settings={{
                    ...value,
                    theme,
                    orientation: 'landscape',
                    rotation: [],
                    night_dim: false,
                }}
                campaigns={[]}
                now={now}
                preview
                className="size-full"
            />
        </span>
    );
}

/** The time, refreshed once a minute (enough for the thumbnails). */
function useMinute(): Date {
    const [now, setNow] = useState(() => new Date());

    useEffect(() => {
        const id = window.setInterval(() => setNow(new Date()), 60_000);

        return () => window.clearInterval(id);
    }, []);

    return now;
}
