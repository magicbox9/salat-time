import { cn } from '@/lib/utils';
import { RotationPanel } from '../screen/rotation-panel';
import { BigClock, Dates, Lang, NextUp, Time } from '../screen/parts';
import type { ThemeProps } from './shared';
import { ExtraTimes, TomorrowTag } from './shared';

/**
 * "Minimal": black, white and one accent, very large type — for small
 * screens or a screen seen from the back of the hall. The next prayer is
 * the one line drawn in the accent colour.
 */
export function MinimalTheme(props: ThemeProps) {
    return (
        <div className="relative size-full overflow-hidden bg-black">
            {props.layout === 'landscape' ? (
                <Landscape {...props} />
            ) : (
                <Portrait {...props} />
            )}
        </div>
    );
}

function List({
    model,
    text,
    nameClass,
    timeClass,
    rowClass,
}: ThemeProps & { nameClass: string; timeClass: string; rowClass: string }) {
    return (
        <ul className="flex flex-col">
            {model.settings.show_iqama && (
                <li
                    aria-hidden
                    className={cn(
                        'flex items-center gap-[2cqmin] text-white/50',
                        rowClass,
                    )}
                >
                    <span className="flex-1" />
                    <span className="w-[3em] text-center">
                        <Lang language={text.primary} className="text-[0.28em]">
                            {text.t('adhan')}
                        </Lang>
                    </span>
                    <span className="w-[22%] text-center">
                        <Lang language={text.primary} className="text-[0.28em]">
                            {text.t('iqama')}
                        </Lang>
                    </span>
                </li>
            )}
            {model.rows.map((row) => (
                <li
                    key={row.prayer}
                    className={cn(
                        'flex items-center gap-[2cqmin] rounded-[1.4cqmin] transition-colors duration-700',
                        rowClass,
                        row.state === 'next' &&
                            'bg-(--d-accent) text-(--d-accent-ink)',
                        row.state === 'next' &&
                            model.phase.kind === 'approaching' &&
                            'd-breathe',
                        row.state === 'current' &&
                            'ring-[0.4cqmin] ring-(--d-accent)',
                        row.state === 'passed' && 'text-white/45',
                    )}
                >
                    <Lang
                        language={text.primary}
                        className={cn('flex-1 font-semibold', nameClass)}
                    >
                        {text.prayer(row.prayer).main}
                    </Lang>
                    <TomorrowTag show={row.tomorrow} text={text} />
                    <Time
                        value={row.time}
                        model={model}
                        className={cn(
                            'w-[3em] text-center font-bold',
                            timeClass,
                        )}
                    />
                    {model.settings.show_iqama && (
                        <Time
                            value={row.tomorrow ? null : row.iqama}
                            model={model}
                            className={cn(
                                'w-[22%] text-center font-medium opacity-70',
                                'text-[0.62em]',
                            )}
                        />
                    )}
                </li>
            ))}
        </ul>
    );
}

function Landscape(props: ThemeProps) {
    const { model, text, slide, hafsReady } = props;

    return (
        <div className="flex size-full flex-col p-[4cqmin]">
            <div className="grid min-h-0 flex-1 grid-cols-[1.05fr_1fr] items-center gap-[5cqmin]">
                <section className="flex flex-col gap-[2.4cqmin]">
                    <BigClock
                        model={model}
                        className="text-[length:min(25cqmin,13.5cqw)] font-bold"
                        secondsClass="text-white/60"
                    />
                    <Dates
                        model={model}
                        text={text}
                        className="text-[3.6cqmin]"
                    />
                    <NextUp
                        model={model}
                        text={text}
                        className="text-[4.4cqmin]"
                    />
                    <ExtraTimes
                        model={model}
                        text={text}
                        className="text-[2.8cqmin]"
                        itemClass="bg-transparent ring-white/25"
                    />
                </section>
                <div className="text-[7.4cqmin]">
                    <List
                        {...props}
                        nameClass="text-[0.7em]"
                        timeClass=""
                        rowClass="px-[2cqmin] py-[0.5cqmin]"
                    />
                </div>
            </div>
            {slide && (
                <div className="mt-[2cqmin] border-t border-white/20 pt-[2cqmin]">
                    <RotationPanel
                        slide={slide}
                        text={text}
                        period={model.period}
                        size={2.6}
                        hafsReady={hafsReady}
                        compact
                    />
                </div>
            )}
        </div>
    );
}

function Portrait(props: ThemeProps) {
    const { model, text, slide, hafsReady } = props;

    return (
        <div className="flex size-full flex-col gap-[2.2cqmin] px-[6cqmin] py-[5cqmin]">
            <section className="flex flex-col items-center gap-[1.6cqmin] text-center">
                <BigClock
                    model={model}
                    className="text-[22cqmin] font-bold"
                    secondsClass="text-white/60"
                />
                <Dates
                    model={model}
                    text={text}
                    className="items-center text-[4.4cqmin]"
                />
                <NextUp
                    model={model}
                    text={text}
                    className="justify-center text-[5cqmin]"
                />
            </section>
            <div className="text-[7.6cqmin]">
                <List
                    {...props}
                    nameClass="text-[0.62em]"
                    timeClass=""
                    rowClass="px-[3cqmin] py-[0.5cqmin]"
                />
            </div>
            <ExtraTimes
                model={model}
                text={text}
                className="justify-center text-[3.6cqmin]"
                itemClass="bg-transparent ring-white/25"
            />
            {slide && (
                <div className="flex min-h-[12cqmin] flex-1 flex-col border-t border-white/20 pt-[3cqmin]">
                    <RotationPanel
                        slide={slide}
                        text={text}
                        period={model.period}
                        size={4}
                        hafsReady={hafsReady}
                        compact
                        className="h-full"
                    />
                </div>
            )}
        </div>
    );
}
