import { Bell, BellOff, Eye, Pause, Play, Volume2 } from 'lucide-react';
import { useEffect, useRef, useState } from 'react';
import { Button } from '@/components/ui/button';
import { useT } from '@/lib/i18n';
import type { AdhanTrack } from '../types';
import type { EditorProps } from './editor-types';
import { RangeRow, Section, Segmented, SelectRow, SwitchRow } from './controls';

/** The adhan on screen: sound or visual only, which recording, Fajr's own, the volume. */
export function AudioSection({
    value,
    onChange,
    errors,
    catalog,
    scope,
}: EditorProps) {
    const t = useT();
    const [listening, setListening] = useState<string | null>(null);
    const player = useRef<HTMLAudioElement | null>(null);

    useEffect(() => () => player.current?.pause(), []);

    const listen = (track: AdhanTrack | undefined) => {
        if (!track) {
            return;
        }

        if (listening === track.id) {
            player.current?.pause();
            setListening(null);

            return;
        }

        player.current?.pause();
        const audio = new Audio(track.url);
        audio.volume = value.volume / 100;
        audio.addEventListener('ended', () => setListening(null));
        player.current = audio;
        void audio
            .play()
            .then(() => setListening(track.id))
            .catch(() => setListening(null));
    };

    const choices = [
        { value: '', label: t('display.adhan_default') },
        ...catalog.map((track) => ({ value: track.id, label: track.name })),
    ];
    const selected =
        catalog.find((track) => track.id === value.adhan_id) ?? catalog[0];
    const fajr = catalog.find((track) => track.id === value.fajr_adhan_id);

    return (
        <Section
            id="audio"
            title={t('display.section_audio')}
            description={t('display.section_audio_hint')}
            icon={Volume2}
        >
            <Segmented
                label={t('display.adhan_mode')}
                value={value.adhan_mode}
                onChange={(adhan_mode) => onChange({ adhan_mode })}
                options={[
                    {
                        value: 'sound',
                        label: t('display.adhan_mode_sound'),
                        icon: Bell,
                    },
                    {
                        value: 'visual',
                        label: t('display.adhan_mode_visual'),
                        icon: Eye,
                    },
                    {
                        value: 'off',
                        label: t('display.adhan_mode_off'),
                        icon: BellOff,
                    },
                ]}
                hint={t(`display.adhan_mode_${value.adhan_mode}_hint`)}
            />

            {value.adhan_mode === 'sound' && (
                <>
                    {catalog.length === 0 ? (
                        <p className="rounded-xl bg-muted px-4 py-3 text-sm text-muted-foreground">
                            {t('display.adhan_none')}
                        </p>
                    ) : (
                        <>
                            <div className="flex items-end gap-2">
                                <div className="min-w-0 flex-1">
                                    <SelectRow
                                        label={t('display.adhan_choice')}
                                        value={value.adhan_id ?? ''}
                                        options={choices}
                                        onChange={(id) =>
                                            onChange({ adhan_id: id || null })
                                        }
                                        error={errors.adhan_id}
                                    />
                                </div>
                                <ListenButton
                                    playing={listening === selected?.id}
                                    onClick={() => listen(selected)}
                                />
                            </div>
                            <div className="flex items-end gap-2">
                                <div className="min-w-0 flex-1">
                                    <SelectRow
                                        label={t('display.fajr_adhan_choice')}
                                        value={value.fajr_adhan_id ?? ''}
                                        options={[
                                            {
                                                value: '',
                                                label: t('display.fajr_same'),
                                            },
                                            ...choices.slice(1),
                                        ]}
                                        onChange={(id) =>
                                            onChange({
                                                fajr_adhan_id: id || null,
                                            })
                                        }
                                        error={errors.fajr_adhan_id}
                                    />
                                </div>
                                <ListenButton
                                    playing={!!fajr && listening === fajr.id}
                                    disabled={!fajr}
                                    onClick={() => listen(fajr)}
                                />
                            </div>
                        </>
                    )}
                    <RangeRow
                        label={t('display.volume')}
                        value={value.volume}
                        min={0}
                        max={100}
                        step={5}
                        unit="%"
                        onChange={(volume) => onChange({ volume })}
                        error={errors.volume}
                    />
                    {scope === 'personal' && (
                        <SwitchRow
                            label={t('display.muted')}
                            hint={t('display.muted_hint')}
                            checked={value.muted ?? false}
                            onChange={(muted) => onChange({ muted })}
                        />
                    )}
                    <p className="text-xs text-muted-foreground">
                        {t('display.autoplay_note')}
                    </p>
                </>
            )}
        </Section>
    );
}

function ListenButton({
    playing,
    onClick,
    disabled = false,
}: {
    playing: boolean;
    onClick: () => void;
    disabled?: boolean;
}) {
    const t = useT();

    return (
        <Button
            type="button"
            variant="outline"
            size="icon"
            onClick={onClick}
            disabled={disabled}
            aria-label={
                playing ? t('display.stop_listening') : t('display.listen')
            }
            title={playing ? t('display.stop_listening') : t('display.listen')}
        >
            {playing ? (
                <Pause className="size-4" />
            ) : (
                <Play className="size-4" />
            )}
        </Button>
    );
}
