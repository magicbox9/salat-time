import type { CSSProperties } from 'react';
import { QuranFonts } from '@/components/quran/quran-fonts';
import { cn } from '@/lib/utils';
import { useBurnInShift } from '../hooks/use-burn-in';
import { useHafsFont } from '../hooks/use-hafs-font';
import { useStage } from '../hooks/use-stage';
import { buildModel } from '../lib/model';
import { slideAt, slideLists } from '../lib/rotation';
import { screenText } from '../lib/text';
import { ArabesqueTheme } from '../themes/arabesque';
import { ClassicTheme } from '../themes/classic';
import { MinimalTheme } from '../themes/minimal';
import { NightSkyTheme } from '../themes/night-sky';
import { stageVars } from '../themes/palette';
import type { ThemeProps } from '../themes/shared';
import type {
    DisplayPayload,
    DisplaySettings,
    ScreenCampaign,
    Simulation,
    ThemeName,
} from '../types';
import { NoTimes } from './no-times';
import { PhaseOverlay } from './phase-overlay';
import { ScreenStyles } from './screen-styles';

const THEMES: Record<ThemeName, (props: ThemeProps) => React.ReactNode> = {
    classic: ClassicTheme,
    night_sky: NightSkyTheme,
    arabesque: ArabesqueTheme,
    minimal: MinimalTheme,
};

type Props = {
    payload: DisplayPayload;
    settings: DisplaySettings;
    campaigns: ScreenCampaign[];
    now: Date;
    /** The settings page's live preview: no quarter turn, no pixel shift. */
    preview?: boolean;
    simulation?: Simulation | null;
    className?: string;
    /** Controls and prompts, drawn above the screen (in the page's own language). */
    children?: React.ReactNode;
};

/**
 * The display itself, for a TV, a tablet or the settings preview. All sizes
 * are relative to its own frame (container units), so the same screen fills
 * a 1080p or 4K TV, a tablet or a small 16:9 preview without a layout shift.
 */
export function DisplayScreen({
    payload,
    settings,
    campaigns,
    now,
    preview = false,
    simulation = null,
    className,
    children,
}: Props) {
    const stage = useStage(settings.orientation, !preview);
    const hafsReady = useHafsFont();
    const shift = useBurnInShift(!preview);
    const model = buildModel(payload, settings, now, simulation);
    const text = screenText(payload, settings);
    const lists = slideLists(payload, settings, campaigns, model.period, now);
    const current = slideAt(lists, now.getTime(), settings.rotation_seconds);
    const Theme = THEMES[settings.theme] ?? ClassicTheme;
    // No colour chosen for the screen: the theme's own gold (as the settings
    // page says), not the site's accent, which is made for light pages.
    const accent = settings.accent_color;
    const frame: CSSProperties = stage.rotate
        ? {
              width: stage.size.height,
              height: stage.size.width,
              left: '50%',
              top: '50%',
              transform: 'translate(-50%, -50%) rotate(90deg)',
          }
        : { inset: 0 };

    return (
        <div
            ref={stage.ref}
            className={cn('relative overflow-hidden bg-black', className)}
        >
            <ScreenStyles />
            <QuranFonts preloadFace="hafs" />
            <div
                className="d-stage absolute"
                style={frame}
                dir={text.primary === 'ar' ? 'rtl' : 'ltr'}
                lang={text.primary}
            >
                <div
                    className="relative size-full transition-transform duration-[2000ms]"
                    style={{
                        containerType: 'size',
                        ...stageVars(settings.theme, accent),
                        transform:
                            shift.x || shift.y
                                ? `translate(${shift.x}px, ${shift.y}px)`
                                : undefined,
                    }}
                >
                    {model.day ? (
                        <Theme
                            model={model}
                            text={text}
                            payload={payload}
                            layout={stage.layout}
                            slide={current?.slide ?? null}
                            hafsReady={hafsReady}
                        />
                    ) : (
                        <NoTimes
                            model={model}
                            text={text}
                            payload={payload}
                            layout={stage.layout}
                        />
                    )}
                    <PhaseOverlay
                        model={model}
                        text={text}
                        afterPrayer={payload.rotation.after_prayer}
                    />
                    <div
                        className={cn(
                            'pointer-events-none absolute inset-0 z-30 bg-black transition-opacity duration-[3000ms]',
                            model.dimmed ? 'opacity-70' : 'opacity-0',
                        )}
                        aria-hidden
                    />
                </div>
            </div>
            {children}
        </div>
    );
}
