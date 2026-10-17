import { Head } from '@inertiajs/react';
import { useEffect, useRef, useState } from 'react';
import { useActivity } from '@/components/display/hooks/use-idle';
import { useAdhanAudio } from '@/components/display/hooks/use-adhan-audio';
import {
    PERSONAL_MUTE_SLUG,
    useDeviceMute,
} from '@/components/display/hooks/use-device-mute';
import { useDisplayData } from '@/components/display/hooks/use-display-data';
import { useTicker } from '@/components/display/hooks/use-ticker';
import { useWakeLock } from '@/components/display/hooks/use-wake-lock';
import { buildModel } from '@/components/display/lib/model';
import {
    PERSONAL_STORAGE_KEY,
    mergeSettings,
    readGuestSettings,
} from '@/components/display/lib/settings';
import { zoneNow } from '@/components/display/lib/zone';
import { ChooseMosque } from '@/components/display/screen/choose-mosque';
import { DisplayScreen } from '@/components/display/screen/display-screen';
import { ScreenControls } from '@/components/display/screen/screen-controls';
import { SoundPrompt } from '@/components/display/screen/sound-prompt';
import type {
    DisplayPayload,
    DisplaySettings,
} from '@/components/display/types';
import { useDocumentLocale } from '@/layouts/site-layout';
import { useT } from '@/lib/i18n';

type Props = {
    mode: 'mosque' | 'personal';
    payload: DisplayPayload | null;
    /** A signed-in visitor's own settings (personal mode), null before any are saved. */
    personal: DisplaySettings | null;
    personalDefaults?: DisplaySettings;
    signedIn: boolean;
    settingsUrl: string | null;
};

/**
 * The full-screen display: GET /mosques/{slug}/display (the mosque's own
 * settings) and GET /display (the visitor's mosque, their own settings).
 * Keeps the screen awake, refreshes its data, runs offline on the last copy
 * and plays the adhan when allowed.
 */
export default function Screen(props: Props) {
    useDocumentLocale();
    const t = useT();

    if (!props.payload) {
        return (
            <>
                <Head title={t('display.title')} />
                <ChooseMosque />
            </>
        );
    }

    return <LiveScreen {...props} payload={props.payload} />;
}

function LiveScreen({
    mode,
    payload: initial,
    personal,
    personalDefaults,
    signedIn,
    settingsUrl,
}: Props & { payload: DisplayPayload }) {
    const t = useT();
    const now = useTicker();
    const date = zoneNow(initial.timezone, now).date;
    const data = useDisplayData(initial, date);
    const payload = data.payload ?? initial;
    const [guest, setGuest] = useState<unknown>(null);

    // A guest's personal settings live in this browser (and follow changes made in another tab).
    useEffect(() => {
        if (mode !== 'personal' || signedIn) {
            return;
        }

        setGuest(readGuestSettings());
        const onStorage = (event: StorageEvent) => {
            if (event.key === PERSONAL_STORAGE_KEY) {
                setGuest(readGuestSettings());
            }
        };
        window.addEventListener('storage', onStorage);

        return () => window.removeEventListener('storage', onStorage);
    }, [mode, signedIn]);

    const settings: DisplaySettings =
        mode === 'mosque'
            ? payload.settings
            : mergeSettings(
                  personalDefaults ?? payload.settings,
                  signedIn ? personal : guest,
              );
    const [muted, setMuted] = useDeviceMute(
        mode === 'mosque' ? payload.mosque.slug : PERSONAL_MUTE_SLUG,
        settings.muted ?? false,
    );
    const model = buildModel(payload, settings, now);
    const audio = useAdhanAudio({
        phase: model.phase,
        nowMinutes: model.zone.minutes,
        date: model.zone.date,
        settings,
        catalog: payload.catalog,
        muted,
        enabled: true,
    });
    const active = useActivity();
    useWakeLock(true);

    // The first touch anywhere also allows sound.
    const unlock = useRef(audio.unlock);

    useEffect(() => {
        unlock.current = audio.unlock;
    });

    useEffect(() => {
        if (!audio.needsUnlock) {
            return;
        }

        const once = () => unlock.current();
        window.addEventListener('pointerdown', once, { once: true });
        window.addEventListener('keydown', once, { once: true });

        return () => {
            window.removeEventListener('pointerdown', once);
            window.removeEventListener('keydown', once);
        };
    }, [audio.needsUnlock]);

    return (
        <>
            <Head title={`${payload.mosque.name} · ${t('display.title')}`} />
            <div
                className="fixed inset-0 overflow-hidden bg-black select-none"
                style={{ cursor: active ? 'auto' : 'none' }}
            >
                <DisplayScreen
                    payload={payload}
                    settings={settings}
                    campaigns={data.campaigns}
                    now={now}
                    className="size-full"
                >
                    <ScreenControls
                        visible={active}
                        muted={muted}
                        onMute={setMuted}
                        sound={audio.soundOn}
                        settingsUrl={settingsUrl}
                        exitUrl={
                            mode === 'mosque'
                                ? `/mosques/${payload.mosque.slug}`
                                : '/'
                        }
                        offline={data.offline}
                    />
                    {audio.needsUnlock && (
                        <SoundPrompt onUnlock={audio.unlock} />
                    )}
                </DisplayScreen>
            </div>
        </>
    );
}
