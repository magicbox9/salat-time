import { Volume2, VolumeX, X } from 'lucide-react';
import { useEffect, useId, useRef } from 'react';
import { Button } from '@/components/ui/button';
import { useT } from '@/lib/i18n';
import { Clock, usePrayerName } from '../bits';
import type { HubPrefs } from '../types';
import type { AdhanMoment } from './use-adhan';

type Props = {
    moment: AdhanMoment;
    mosqueName: string;
    prefs: HubPrefs;
    playing: boolean;
    blocked: boolean;
    onPlay: () => void;
    onStop: () => void;
    onClose: () => void;
};

/**
 * The visual adhan: a calm full-screen moment over a night sky with an
 * eight-pointed star lattice. Escape or "Close" dismisses it (and stops
 * the sound).
 */
export function AdhanOverlay({
    moment,
    mosqueName,
    prefs,
    playing,
    blocked,
    onPlay,
    onStop,
    onClose,
}: Props) {
    const t = useT();
    const name = usePrayerName();
    const titleId = useId();
    const close = useRef<HTMLButtonElement>(null);
    const dialog = useRef<HTMLDivElement>(null);
    const patternId = `${titleId.replace(/:/g, '')}-stars`;

    useEffect(() => {
        const previous = document.activeElement as HTMLElement | null;
        close.current?.focus();
        const onKey = (event: KeyboardEvent) => {
            if (event.key === 'Escape') {
                onClose();

                return;
            }

            // A modal dialog: Tab cycles through its own buttons only.
            const box = dialog.current;

            if (event.key !== 'Tab' || !box) {
                return;
            }

            const items = Array.from(
                box.querySelectorAll<HTMLElement>('button:not([disabled])'),
            );
            const first = items[0];
            const last = items.at(-1);
            const active = document.activeElement;

            if (!first || !last) {
                return;
            }

            if (!box.contains(active)) {
                event.preventDefault();
                first.focus();
            } else if (event.shiftKey && active === first) {
                event.preventDefault();
                last.focus();
            } else if (!event.shiftKey && active === last) {
                event.preventDefault();
                first.focus();
            }
        };
        document.addEventListener('keydown', onKey);

        return () => {
            document.removeEventListener('keydown', onKey);
            previous?.focus?.();
        };
        // eslint-disable-next-line react-hooks/exhaustive-deps
    }, [moment.key]);

    return (
        <div
            ref={dialog}
            role="dialog"
            aria-modal="true"
            aria-labelledby={titleId}
            className="fixed inset-0 z-[70] flex items-center justify-center overflow-hidden bg-[radial-gradient(ellipse_at_top,oklch(0.3_0.06_200),oklch(0.14_0.035_235)_70%)] px-6 text-white motion-safe:animate-in motion-safe:duration-700 motion-safe:fade-in-0"
        >
            <svg
                aria-hidden
                className="absolute inset-0 h-full w-full opacity-[0.07]"
            >
                <defs>
                    <pattern
                        id={patternId}
                        width="64"
                        height="64"
                        patternUnits="userSpaceOnUse"
                    >
                        <g fill="none" stroke="white" strokeWidth="1">
                            <rect x="16" y="16" width="32" height="32" />
                            <rect
                                x="16"
                                y="16"
                                width="32"
                                height="32"
                                transform="rotate(45 32 32)"
                            />
                            <circle cx="32" cy="32" r="6" />
                        </g>
                    </pattern>
                </defs>
                <rect width="100%" height="100%" fill={`url(#${patternId})`} />
            </svg>
            <div
                aria-hidden
                className="absolute top-1/2 left-1/2 size-[36rem] -translate-x-1/2 -translate-y-1/2 rounded-full bg-[radial-gradient(circle,oklch(0.82_0.12_85/0.22),transparent_62%)] motion-safe:animate-pulse"
            />

            <button
                ref={close}
                type="button"
                onClick={onClose}
                className="absolute end-4 top-4 rounded-full p-2 text-white/70 transition hover:bg-white/10 hover:text-white focus-visible:ring-2 focus-visible:ring-gold focus-visible:outline-none"
                aria-label={t('hub.adhan_close')}
            >
                <X className="size-6" />
            </button>

            <div className="relative max-w-2xl text-center">
                <p className="text-sm font-semibold tracking-[0.3em] text-gold uppercase">
                    {t('hub.adhan_eyebrow')}
                </p>
                <h2
                    id={titleId}
                    className="mt-4 text-6xl font-semibold tracking-tight sm:text-8xl"
                >
                    {name(moment.prayer)}
                </h2>
                <p className="mt-5 text-lg text-white/80 sm:text-xl">
                    {t('hub.adhan_time_for', { prayer: name(moment.prayer) })}
                </p>
                <p className="mt-3 text-4xl font-light text-gold sm:text-5xl">
                    <Clock value={moment.time} prefs={prefs} />
                </p>
                <p className="mt-6 text-sm text-white/60">
                    <bdi>{mosqueName}</bdi>
                </p>

                <div className="mt-10 flex flex-wrap items-center justify-center gap-3">
                    {blocked && !playing && (
                        <Button
                            size="lg"
                            onClick={onPlay}
                            className="bg-gold text-[oklch(0.25_0.04_80)] hover:bg-gold/90"
                        >
                            <Volume2 />
                            {t('hub.adhan_play')}
                        </Button>
                    )}
                    {playing && (
                        <Button
                            size="lg"
                            variant="outline"
                            onClick={onStop}
                            className="border-white/30 bg-white/10 text-white hover:bg-white/20 hover:text-white"
                        >
                            <VolumeX />
                            {t('hub.adhan_stop')}
                        </Button>
                    )}
                    <Button
                        size="lg"
                        variant="ghost"
                        onClick={onClose}
                        className="text-white/80 hover:bg-white/10 hover:text-white"
                    >
                        {t('hub.adhan_close')}
                    </Button>
                </div>
            </div>
        </div>
    );
}
