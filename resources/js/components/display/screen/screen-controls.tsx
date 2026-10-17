import { Link } from '@inertiajs/react';
import {
    ArrowLeft,
    Maximize,
    Minimize,
    Settings2,
    Volume2,
    VolumeX,
    WifiOff,
} from 'lucide-react';
import { useEffect, useState } from 'react';
import { useT } from '@/lib/i18n';
import { cn } from '@/lib/utils';

type Props = {
    visible: boolean;
    muted: boolean;
    onMute: (muted: boolean) => void;
    /** The adhan is set to play a sound (otherwise the mute switch is not offered). */
    sound: boolean;
    settingsUrl: string | null;
    exitUrl: string;
    offline: boolean;
};

/**
 * Discreet controls that appear when the mouse moves or the screen is
 * touched: mute, full screen, settings (for those allowed) and a way out.
 * A small mark stays in the corner while the screen runs on saved data.
 */
export function ScreenControls({
    visible,
    muted,
    onMute,
    sound,
    settingsUrl,
    exitUrl,
    offline,
}: Props) {
    const t = useT();
    const [fullscreen, setFullscreen] = useState(false);

    useEffect(() => {
        const update = () => setFullscreen(document.fullscreenElement !== null);
        document.addEventListener('fullscreenchange', update);

        return () => document.removeEventListener('fullscreenchange', update);
    }, []);

    const toggleFullscreen = () => {
        if (document.fullscreenElement) {
            void document.exitFullscreen().catch(() => undefined);
        } else {
            void document.documentElement
                .requestFullscreen?.()
                .catch(() => undefined);
        }
    };

    const button =
        'flex size-12 items-center justify-center rounded-full text-white/90 transition-colors hover:bg-white/15 focus-visible:bg-white/15 focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-white';

    return (
        <>
            {offline && (
                <span
                    className="absolute end-3 top-3 z-50 flex items-center gap-1.5 rounded-full bg-black/55 px-3 py-1 text-xs text-white/80 backdrop-blur"
                    role="status"
                >
                    <WifiOff className="size-3.5" aria-hidden />
                    {t('display.offline')}
                </span>
            )}
            <nav
                aria-label={t('display.controls')}
                className={cn(
                    'absolute end-4 bottom-4 z-50 flex items-center gap-1 rounded-full bg-black/60 p-1.5 shadow-2xl ring-1 ring-white/15 backdrop-blur-md transition-opacity duration-500 focus-within:opacity-100',
                    visible ? 'opacity-100' : 'pointer-events-none opacity-0',
                )}
            >
                <Link
                    href={exitUrl}
                    className={button}
                    aria-label={t('display.exit')}
                    title={t('display.exit')}
                >
                    <ArrowLeft className="size-5 rtl:rotate-180" />
                </Link>
                {sound && (
                    <button
                        type="button"
                        className={button}
                        onClick={() => onMute(!muted)}
                        aria-pressed={muted}
                        aria-label={
                            muted ? t('display.unmute') : t('display.mute')
                        }
                        title={muted ? t('display.unmute') : t('display.mute')}
                    >
                        {muted ? (
                            <VolumeX className="size-5" />
                        ) : (
                            <Volume2 className="size-5" />
                        )}
                    </button>
                )}
                <button
                    type="button"
                    className={button}
                    onClick={toggleFullscreen}
                    aria-label={
                        fullscreen
                            ? t('display.exit_fullscreen')
                            : t('display.fullscreen')
                    }
                    title={
                        fullscreen
                            ? t('display.exit_fullscreen')
                            : t('display.fullscreen')
                    }
                >
                    {fullscreen ? (
                        <Minimize className="size-5" />
                    ) : (
                        <Maximize className="size-5" />
                    )}
                </button>
                {settingsUrl && (
                    <Link
                        href={settingsUrl}
                        className={button}
                        aria-label={t('display.open_settings')}
                        title={t('display.open_settings')}
                    >
                        <Settings2 className="size-5" />
                    </Link>
                )}
            </nav>
        </>
    );
}
