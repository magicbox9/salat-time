import { Sun, Users } from 'lucide-react';
import { cn } from '@/lib/utils';
import type { ScreenModel } from '../lib/model';
import type { Slide } from '../lib/rotation';
import type { ScreenText } from '../lib/text';
import { Lang, Time } from '../screen/parts';
import type { DisplayPayload } from '../types';

export type ThemeProps = {
    model: ScreenModel;
    text: ScreenText;
    payload: DisplayPayload;
    layout: 'landscape' | 'portrait';
    slide: Slide | null;
    hafsReady: boolean;
};

/** The mosque's own picture behind the screen, darkened so the times stay readable. */
export function BackgroundImage({ url }: { url: string | null }) {
    if (!url) {
        return null;
    }

    return (
        <div className="pointer-events-none absolute inset-0" aria-hidden>
            <img src={url} alt="" className="size-full object-cover" />
            <div className="absolute inset-0 bg-[linear-gradient(180deg,rgb(3_20_16/0.72),rgb(3_20_16/0.86))]" />
        </div>
    );
}

/**
 * Large folded planes and hairline seams, as the Mac app's backdrop inspired
 * by Education City Mosque, with a faint field of points of light at the top.
 */
export function FacetBackdrop({ className }: { className?: string }) {
    const facets: [string, number][] = [
        ['0,0 34,0 16,36', 0.05],
        ['34,0 72,0 52,46 16,36', 0.075],
        ['72,0 100,0 100,58 52,46', 0.035],
        ['0,36 16,36 52,46 30,100 0,100', 0.06],
        ['52,46 100,58 100,100 30,100', 0.03],
        ['0,0 16,36 0,36', 0.045],
    ];

    return (
        <svg
            viewBox="0 0 100 100"
            preserveAspectRatio="none"
            className={cn(
                'pointer-events-none absolute inset-0 size-full',
                className,
            )}
            aria-hidden
        >
            {facets.map(([points, alpha]) => (
                <polygon
                    key={points}
                    points={points}
                    fill="white"
                    fillOpacity={alpha}
                    stroke="white"
                    strokeOpacity={0.05}
                    strokeWidth={0.15}
                />
            ))}
        </svg>
    );
}

/** Sunrise and Jumu'a, as small tiles (each can be switched off). */
export function ExtraTimes({
    model,
    text,
    className,
    itemClass,
}: {
    model: ScreenModel;
    text: ScreenText;
    className?: string;
    itemClass?: string;
}) {
    const s = model.settings;
    const showJumua = s.show_jumua && model.jumua.length > 0;

    if (!(s.show_shuruq && model.shuruq) && !showJumua) {
        return null;
    }

    return (
        <div className={cn('flex flex-wrap gap-[1.2cqmin]', className)}>
            {s.show_shuruq && model.shuruq && (
                <span
                    className={cn(
                        'flex items-center gap-[0.8cqmin] rounded-[1.2cqmin] bg-(--d-panel) px-[1.4cqmin] py-[0.7cqmin] ring-1 ring-(--d-line)',
                        itemClass,
                    )}
                >
                    <Sun
                        className="size-[1.1em] text-(--d-accent)"
                        aria-hidden
                    />
                    <Lang language={text.primary} className="text-(--d-muted)">
                        {text.prayer('shuruq').main}
                    </Lang>
                    <Time
                        value={model.shuruq}
                        model={model}
                        className="font-semibold"
                    />
                </span>
            )}
            {showJumua && (
                <span
                    className={cn(
                        'flex items-center gap-[0.8cqmin] rounded-[1.2cqmin] bg-(--d-panel) px-[1.4cqmin] py-[0.7cqmin] ring-1 ring-(--d-line)',
                        itemClass,
                    )}
                >
                    <Users
                        className="size-[1.1em] text-(--d-accent)"
                        aria-hidden
                    />
                    <Lang language={text.primary} className="text-(--d-muted)">
                        {text.prayer('jumua').main}
                    </Lang>
                    {model.jumua.map((time, i) => (
                        <span
                            key={time + i}
                            className="flex items-center gap-[0.8cqmin] font-semibold"
                        >
                            {i > 0 && (
                                <span className="text-(--d-muted)">·</span>
                            )}
                            <Time value={time} model={model} />
                        </span>
                    ))}
                </span>
            )}
        </div>
    );
}

/** The iqama under or beside a time: "13:40" (or nothing when it is hidden). */
export function IqamaTime({
    value,
    model,
    text,
    className,
}: {
    value: string | null;
    model: ScreenModel;
    text: ScreenText;
    className?: string;
}) {
    if (!model.settings.show_iqama || !value) {
        return null;
    }

    return (
        <span
            className={cn(
                'flex items-baseline gap-[0.5em] text-(--d-muted)',
                className,
            )}
        >
            <Lang language={text.primary}>{text.t('iqama')}</Lang>
            <Time
                value={value}
                model={model}
                className="font-semibold text-(--d-fg)"
            />
        </span>
    );
}

/** Small "Tomorrow" tag on a row that shows the next day's time. */
export function TomorrowTag({
    show,
    text,
}: {
    show: boolean;
    text: ScreenText;
}) {
    if (!show) {
        return null;
    }

    return (
        <Lang
            language={text.primary}
            className="rounded-full bg-(--d-panel) px-[0.8em] py-[0.1em] text-[0.55em] font-medium text-(--d-muted) ring-1 ring-(--d-line)"
        >
            {text.t('tomorrow')}
        </Lang>
    );
}
