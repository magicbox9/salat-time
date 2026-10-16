import { BellOff, Eye, Play, Square, Volume2 } from 'lucide-react';
import { useId } from 'react';
import { Button } from '@/components/ui/button';
import { useT } from '@/lib/i18n';
import type { AdhanTrack, HubPrefs } from '../types';
import { Segmented, SwitchRow } from './controls';

type Props = {
    prefs: HubPrefs;
    tracks: AdhanTrack[];
    loaded: boolean;
    playing: boolean;
    onChange: (change: Partial<HubPrefs>) => void;
    onPreview: (url: string) => void;
    onStop: () => void;
};

/** The adhan inside the page: off, sound or visual only; the recording; mute. */
export function AdhanSettings({
    prefs,
    tracks,
    loaded,
    playing,
    onChange,
    onPreview,
    onStop,
}: Props) {
    const t = useT();
    const selectId = useId();
    const noRecording = loaded && tracks.length === 0;
    const selected =
        tracks.find((track) => track.id === prefs.adhan_id) ??
        tracks[0] ??
        null;

    return (
        <>
            <Segmented
                label={t('hub.adhan_mode')}
                value={prefs.adhan}
                onChange={(adhan) => onChange({ adhan })}
                options={[
                    {
                        value: 'off',
                        label: t('hub.adhan_off'),
                        icon: <BellOff className="size-3.5" />,
                    },
                    {
                        value: 'sound',
                        label: t('hub.adhan_sound'),
                        icon: <Volume2 className="size-3.5" />,
                        disabled: noRecording,
                    },
                    {
                        value: 'visual',
                        label: t('hub.adhan_visual'),
                        icon: <Eye className="size-3.5" />,
                    },
                ]}
            />
            <p className="text-xs text-muted-foreground">
                {noRecording
                    ? t('hub.adhan_no_recording')
                    : t(`hub.adhan_${prefs.adhan}_hint`)}
            </p>

            {prefs.adhan === 'sound' && selected && (
                <div className="mt-3 space-y-2">
                    <label
                        htmlFor={selectId}
                        className="block text-sm font-medium"
                    >
                        {t('hub.adhan_choice')}
                    </label>
                    <div className="flex items-center gap-2">
                        <select
                            id={selectId}
                            value={selected.id}
                            onChange={(event) =>
                                onChange({ adhan_id: event.target.value })
                            }
                            className="h-9 min-w-0 flex-1 rounded-md border border-input bg-background px-3 text-sm shadow-xs focus-visible:ring-[3px] focus-visible:ring-ring/50 focus-visible:outline-none"
                        >
                            {tracks.map((track) => (
                                <option key={track.id} value={track.id}>
                                    {track.name}
                                </option>
                            ))}
                        </select>
                        <Button
                            type="button"
                            variant="outline"
                            size="icon"
                            onClick={() =>
                                playing ? onStop() : onPreview(selected.url)
                            }
                            aria-label={
                                playing
                                    ? t('hub.adhan_stop')
                                    : t('hub.adhan_preview')
                            }
                        >
                            {playing ? (
                                <Square className="size-4" />
                            ) : (
                                <Play className="size-4" />
                            )}
                        </Button>
                    </div>
                </div>
            )}

            {prefs.adhan !== 'off' && (
                <SwitchRow
                    label={t('hub.adhan_mute')}
                    hint={t('hub.adhan_mute_hint')}
                    checked={prefs.muted}
                    disabled={prefs.adhan !== 'sound'}
                    onChange={(muted) => onChange({ muted })}
                />
            )}
        </>
    );
}
