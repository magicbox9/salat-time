import { cn } from '@/lib/utils';
import type { ScreenModel } from '../lib/model';
import type { ScreenText } from '../lib/text';
import { isRtl } from '../lib/text';
import {
    clockParts,
    countdown,
    formatTime,
    gregorianDate,
    hijriDate,
} from '../lib/zone';
import type { DisplayLanguage, DisplayPayload } from '../types';

/** Numbers and times stay left-to-right in every language. */
export function Ltr({
    children,
    className,
}: {
    children: React.ReactNode;
    className?: string;
}) {
    return (
        <span dir="ltr" className={cn('tabular-nums', className)}>
            {children}
        </span>
    );
}

/** A text in its own language (Arabic gets its direction and face). */
export function Lang({
    language,
    children,
    className,
}: {
    language: DisplayLanguage;
    children: React.ReactNode;
    className?: string;
}) {
    return (
        <span
            lang={language}
            dir={isRtl(language) ? 'rtl' : 'ltr'}
            className={cn(isRtl(language) && 'font-arabic', className)}
        >
            {children}
        </span>
    );
}

/** The main language large, the second one under it. */
export function Dual({
    text,
    main,
    second,
    className,
    mainClass,
    secondClass,
}: {
    text: ScreenText;
    main: string;
    second: string | null;
    className?: string;
    mainClass?: string;
    secondClass?: string;
}) {
    return (
        <span className={cn('flex flex-col items-start', className)}>
            <Lang language={text.primary} className={mainClass}>
                {main}
            </Lang>
            {second && text.secondary && second !== main && (
                <Lang
                    language={text.secondary}
                    className={cn('text-(--d-muted)', secondClass)}
                >
                    {second}
                </Lang>
            )}
        </span>
    );
}

/** The big live clock of the mosque's time zone. */
export function BigClock({
    model,
    className,
    secondsClass,
}: {
    model: ScreenModel;
    className?: string;
    secondsClass?: string;
}) {
    const clock = clockParts(
        model.zone,
        model.settings.clock,
        model.settings.languages[0],
    );

    return (
        <Ltr
            className={cn(
                'inline-flex items-baseline leading-none font-semibold tracking-tight',
                className,
            )}
        >
            <span>{clock.main}</span>
            {model.settings.show_seconds && (
                <span
                    className={cn(
                        'ms-[0.12em] text-[0.42em] font-medium text-(--d-muted)',
                        secondsClass,
                    )}
                >
                    {clock.seconds}
                </span>
            )}
            {clock.suffix && (
                <span className="ms-[0.2em] text-[0.3em] font-medium text-(--d-muted)">
                    {clock.suffix}
                </span>
            )}
        </Ltr>
    );
}

/** Gregorian date in the main language, Hijri date under it. */
export function Dates({
    model,
    text,
    className,
    hijriClass,
}: {
    model: ScreenModel;
    text: ScreenText;
    className?: string;
    hijriClass?: string;
}) {
    const s = model.settings;
    const hijri = s.show_hijri
        ? hijriDate(model.zone.date, text.primary, s.hijri_adjust)
        : '';

    return (
        <span className={cn('flex flex-col', className)}>
            <Lang language={text.primary}>
                {gregorianDate(model.zone.date, text.primary)}
            </Lang>
            {hijri && (
                <Lang
                    language={text.primary}
                    className={cn('text-(--d-accent)', hijriClass)}
                >
                    {hijri}
                </Lang>
            )}
        </span>
    );
}

/** "Next prayer · Asr · 1:23:45" (the countdown turns to the accent colour when it is close). */
export function NextUp({
    model,
    text,
    className,
    timeClass,
}: {
    model: ScreenModel;
    text: ScreenText;
    className?: string;
    timeClass?: string;
}) {
    if (!model.next) {
        return null;
    }

    const name = text.prayer(model.next.event.prayer);
    const close = model.phase.kind === 'approaching';

    return (
        <span
            className={cn(
                'flex flex-wrap items-baseline gap-x-[0.6em] gap-y-[0.2em]',
                className,
            )}
        >
            <Lang language={text.primary} className="text-(--d-muted)">
                {text.t('next_prayer')}
            </Lang>
            <Lang language={text.primary} className="font-semibold">
                {name.main}
            </Lang>
            <Ltr
                className={cn(
                    'font-semibold',
                    close ? 'd-breathe text-(--d-accent)' : '',
                    timeClass,
                )}
            >
                {countdown(model.next.remaining, model.settings.show_seconds)}
            </Ltr>
        </span>
    );
}

/** Logo and name of the mosque. */
export function MosqueTitle({
    payload,
    className,
    logoClass,
}: {
    payload: DisplayPayload;
    className?: string;
    logoClass?: string;
}) {
    const m = payload.mosque;

    return (
        <span
            className={cn('flex min-w-0 items-center gap-[0.6em]', className)}
        >
            {m.logo_url && (
                <img
                    src={m.logo_url}
                    alt=""
                    className={cn(
                        'shrink-0 rounded-[0.35em] object-cover',
                        logoClass ?? 'size-[1.8em]',
                    )}
                />
            )}
            <span className="flex min-w-0 flex-col">
                <span className="truncate font-semibold">{m.name}</span>
                {(m.tagline || m.city) && (
                    <span className="truncate text-[0.62em] text-(--d-muted)">
                        {m.tagline || m.city}
                    </span>
                )}
            </span>
        </span>
    );
}

/** A published time in the chosen 12/24 h style. */
export function Time({
    value,
    model,
    className,
}: {
    value: string | null;
    model: ScreenModel;
    className?: string;
}) {
    return (
        <Ltr className={className}>
            {value ? formatTime(value, model.settings.clock) : '—'}
        </Ltr>
    );
}
