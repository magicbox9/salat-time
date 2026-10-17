import {
    BookOpen,
    HandCoins,
    Megaphone,
    Newspaper,
    Sparkles,
} from 'lucide-react';
import { cn } from '@/lib/utils';
import { useFitText } from '../hooks/use-fit-text';
import { money } from '../lib/campaigns';
import type { Slide } from '../lib/rotation';
import { fit, fitSize } from '../lib/rotation';
import type { ScreenText } from '../lib/text';
import type { Verse } from '../types';
import { Lang, Ltr } from './parts';
import { VerseBody } from './verse-body';

type Props = {
    slide: Slide | null;
    text: ScreenText;
    period: 'morning' | 'evening';
    /** Base font size in cqmin (the theme decides how much room the panel has). */
    size: number;
    /** The KFGQPC Hafs face is loaded: the verbatim text (with its ayah marks) can be shown. */
    hafsReady: boolean;
    /** Single line (the minimal theme's band). */
    compact?: boolean;
    className?: string;
};

const ICONS = {
    message: Megaphone,
    verse: BookOpen,
    dhikr: Sparkles,
    post: Newspaper,
    campaign: HandCoins,
};

/** One slide of the rotation: an announcement, a verse, a dhikr, a post or a campaign. */
export function RotationPanel({
    slide,
    text,
    period,
    size,
    hafsReady,
    compact = false,
    className,
}: Props) {
    const body = useFitText<HTMLDivElement>(
        `${slide?.key ?? ''}:${size}:${hafsReady}:${text.primary}:${text.translation}`,
    );

    if (!slide) {
        return null;
    }

    const Icon = ICONS[slide.kind];
    const label = {
        message: text.t('announcement'),
        verse: text.t('verse'),
        dhikr: text.t(period === 'morning' ? 'dhikr_morning' : 'dhikr_evening'),
        post: text.t('news'),
        campaign: text.t('campaign'),
    }[slide.kind];

    return (
        <div
            key={slide.key}
            className={cn(
                'd-fade-up flex min-h-0 flex-col',
                compact ? 'gap-[0.4cqmin]' : 'gap-[1.6cqmin]',
                className,
            )}
        >
            <div className="flex items-center gap-[0.8cqmin] text-[1.9cqmin] font-medium tracking-wide text-(--d-accent) uppercase">
                <Icon className="size-[2.2cqmin] shrink-0" aria-hidden />
                <Lang language={text.primary}>{label}</Lang>
                {slide.kind === 'verse' && (
                    <VerseRef verse={slide.verse} text={text} />
                )}
                {slide.kind === 'dhikr' && slide.dhikr.count > 1 && (
                    <Ltr className="rounded-full border border-(--d-line) px-[0.8cqmin] text-[1.7cqmin] normal-case">
                        ×{slide.dhikr.count}
                    </Ltr>
                )}
            </div>
            <div
                ref={body}
                className="flex min-h-0 flex-1 flex-col justify-center-safe gap-[calc(1.4cqmin*var(--fit,1))] overflow-hidden"
            >
                <SlideBody
                    slide={slide}
                    text={text}
                    size={size}
                    hafsReady={hafsReady}
                    compact={compact}
                />
            </div>
        </div>
    );
}

function VerseRef({ verse, text }: { verse: Verse; text: ScreenText }) {
    const name =
        text.primary === 'ar' ? verse.surah_name_ar : verse.surah_name_en;

    return (
        <span className="ms-auto flex items-center gap-[0.6cqmin] text-(--d-muted) normal-case">
            <Lang language={text.primary === 'ar' ? 'ar' : 'en'}>{name}</Lang>
            <Ltr>{verse.key}</Ltr>
        </span>
    );
}

function SlideBody({
    slide,
    text,
    size,
    hafsReady,
    compact,
}: {
    slide: Slide;
    text: ScreenText;
    size: number;
    hafsReady: boolean;
    compact: boolean;
}) {
    const clamp = compact ? 'line-clamp-2' : '';

    switch (slide.kind) {
        case 'message':
            return (
                <p
                    dir="auto"
                    className={cn(
                        'leading-snug font-medium whitespace-pre-line',
                        clamp,
                    )}
                    style={fit(fitSize(slide.body, size * 1.15, 90))}
                >
                    {slide.body}
                </p>
            );
        case 'verse':
            return (
                <VerseBody
                    verse={slide.verse}
                    text={text}
                    size={size}
                    hafsReady={hafsReady}
                    compact={compact}
                />
            );
        case 'dhikr': {
            const d = slide.dhikr;

            return (
                <>
                    <p
                        lang="ar"
                        dir="rtl"
                        className={cn('font-adhkar leading-[1.9]', clamp)}
                        style={fit(fitSize(d.arabic, size * 1.2, 120))}
                    >
                        {d.arabic}
                    </p>
                    {!compact && d.virtue && (
                        <p
                            lang="ar"
                            dir="rtl"
                            className="font-arabic leading-relaxed text-(--d-muted)"
                            style={fit(
                                fitSize(d.virtue, size * 0.62, 120, 0.6),
                            )}
                        >
                            {d.virtue}
                        </p>
                    )}
                    {!compact && d.source && (
                        <p
                            lang="ar"
                            dir="rtl"
                            className="line-clamp-2 font-arabic text-[1.5cqmin] text-(--d-muted) opacity-80"
                        >
                            {d.source}
                        </p>
                    )}
                </>
            );
        }
        case 'post':
            return (
                <>
                    <p
                        dir="auto"
                        className={cn('leading-tight font-semibold', clamp)}
                        style={fit(fitSize(slide.post.title, size * 1.1, 60))}
                    >
                        {slide.post.title}
                    </p>
                    {!compact && slide.post.excerpt && (
                        <p
                            dir="auto"
                            className="line-clamp-3 leading-relaxed text-(--d-muted)"
                            style={fit(size * 0.6)}
                        >
                            {slide.post.excerpt}
                        </p>
                    )}
                </>
            );
        case 'campaign': {
            const c = slide.campaign;
            const ratio = c.goal ? Math.min(1, c.raised / c.goal) : null;
            const raised = money(c.raised, c.currency, text.primary);

            return (
                <>
                    <p
                        dir="auto"
                        className={cn('leading-tight font-semibold', clamp)}
                        style={fit(fitSize(c.title, size * 1.05, 60))}
                    >
                        {c.title}
                    </p>
                    {ratio !== null && (
                        <div
                            className="h-[1.4cqmin] overflow-hidden rounded-full bg-(--d-panel) ring-1 ring-(--d-line)"
                            role="presentation"
                        >
                            <div
                                className="h-full rounded-full bg-(--d-accent) transition-[width] duration-1000"
                                style={{
                                    width: `${Math.max(2, ratio * 100)}%`,
                                }}
                            />
                        </div>
                    )}
                    <Lang
                        language={text.primary}
                        className="text-[2.2cqmin] text-(--d-muted)"
                    >
                        {c.goal
                            ? text.t('raised_of', {
                                  raised,
                                  goal: money(c.goal, c.currency, text.primary),
                              })
                            : text.t('raised', { raised })}
                    </Lang>
                </>
            );
        }
    }
}
