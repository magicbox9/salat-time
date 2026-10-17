import { cn } from '@/lib/utils';
import type { Row } from '../lib/model';
import { RotationPanel } from '../screen/rotation-panel';
import {
    BigClock,
    Dates,
    Dual,
    Lang,
    MosqueTitle,
    NextUp,
    Time,
} from '../screen/parts';
import { GoldFrame, Rosette, StarPattern } from './arabesque-ornaments';
import type { ThemeProps } from './shared';
import { BackgroundImage, ExtraTimes, TomorrowTag } from './shared';

/**
 * "Arabesque": gold geometry on deep green — eight-point stars, a double
 * frame, the clock in a medallion and the prayers in a ruled table.
 */
export function ArabesqueTheme(props: ThemeProps) {
    const { payload, layout } = props;

    return (
        <div
            className="relative size-full overflow-hidden"
            style={{
                background:
                    'radial-gradient(120% 100% at 50% 0%, #0b4a37 0%, #073426 45%, #041f17 100%)',
            }}
        >
            <BackgroundImage url={payload.background_url} />
            <StarPattern />
            <GoldFrame />
            {layout === 'landscape' ? (
                <Landscape {...props} />
            ) : (
                <Portrait {...props} />
            )}
        </div>
    );
}

function Medallion({
    model,
    size,
    clockClass,
}: {
    model: ThemeProps['model'];
    size: string;
    clockClass: string;
}) {
    return (
        <div
            className={cn(
                'relative flex shrink-0 items-center justify-center rounded-full',
                size,
            )}
        >
            <div className="absolute inset-0 rounded-full border-[0.35cqmin] border-(--d-accent) opacity-80" />
            <div className="absolute inset-[1.4cqmin] rounded-full border-[0.14cqmin] border-[color-mix(in_oklab,var(--d-accent)_45%,transparent)] bg-[radial-gradient(circle,rgb(255_255_255/0.06),transparent_70%)]" />
            <Rosette className="absolute -top-[2.6cqmin] size-[5.2cqmin] rounded-full bg-[#073426] p-[0.5cqmin]" />
            <BigClock model={model} className={clockClass} />
        </div>
    );
}

function Table({
    model,
    text,
    rowClass,
    timeClass,
    nameClass,
    secondClass,
}: ThemeProps & {
    rowClass: string;
    timeClass: string;
    nameClass: string;
    secondClass: string;
}) {
    const showIqama = model.settings.show_iqama;

    return (
        <div className="flex flex-col">
            <div
                className={cn(
                    'flex items-center border-b border-[color-mix(in_oklab,var(--d-accent)_50%,transparent)] pb-[1cqmin] text-[2.2cqmin] tracking-wide text-(--d-accent)',
                    rowClass,
                )}
                aria-hidden
            >
                <span className="flex-1" />
                <Lang
                    language={text.primary}
                    className={cn(
                        timeClass,
                        'w-[27%] shrink-0 text-center text-[2.2cqmin]',
                    )}
                >
                    {text.t('adhan')}
                </Lang>
                {showIqama && (
                    <Lang
                        language={text.primary}
                        className="w-[25%] shrink-0 text-center"
                    >
                        {text.t('iqama')}
                    </Lang>
                )}
            </div>
            {model.rows.map((row: Row) => {
                const name = text.prayer(row.prayer);

                return (
                    <div
                        key={row.prayer}
                        className={cn(
                            'relative flex items-center border-b border-[color-mix(in_oklab,var(--d-accent)_22%,transparent)] transition-colors duration-700',
                            rowClass,
                            row.state === 'next' &&
                                'bg-[linear-gradient(90deg,transparent,color-mix(in_oklab,var(--d-accent)_18%,transparent),transparent)]',
                            row.state === 'next' &&
                                model.phase.kind === 'approaching' &&
                                'd-breathe',
                            row.state === 'current' &&
                                'bg-(--d-accent) text-(--d-accent-ink)',
                            row.state === 'passed' && 'opacity-55',
                        )}
                    >
                        {row.state === 'next' && (
                            <Rosette className="absolute -start-[1.2cqmin] size-[2.6cqmin]" />
                        )}
                        <Dual
                            text={text}
                            main={name.main}
                            second={name.second}
                            className="flex-1"
                            mainClass={nameClass}
                            secondClass={secondClass}
                        />
                        <span className="flex w-[27%] shrink-0 items-center justify-center gap-[1cqmin]">
                            <TomorrowTag show={row.tomorrow} text={text} />
                            <Time
                                value={row.time}
                                model={model}
                                className={cn(timeClass, 'font-semibold')}
                            />
                        </span>
                        {showIqama && (
                            <Time
                                value={row.tomorrow ? null : row.iqama}
                                model={model}
                                className={cn(
                                    timeClass,
                                    'w-[25%] shrink-0 text-center opacity-75',
                                )}
                            />
                        )}
                    </div>
                );
            })}
        </div>
    );
}

const cartouche =
    'rounded-[999px] border-[0.22cqmin] border-[color-mix(in_oklab,var(--d-accent)_65%,transparent)] bg-[rgb(4_31_23/0.55)] backdrop-blur-sm';

function Landscape(props: ThemeProps) {
    const { model, text, payload, slide, hafsReady } = props;

    return (
        <div className="relative flex size-full flex-col gap-[2.4cqmin] px-[6cqmin] pt-[5cqmin] pb-[5cqmin]">
            <header className="flex items-center justify-between gap-[3cqmin]">
                <MosqueTitle
                    payload={payload}
                    className="text-[3.2cqmin]"
                    logoClass="size-[5.6cqmin]"
                />
                <Dates
                    model={model}
                    text={text}
                    className="items-end text-end text-[2.6cqmin]"
                />
            </header>
            <main className="grid min-h-0 flex-1 grid-cols-[0.9fr_1.3fr] items-center gap-[5cqmin] overflow-hidden">
                <section className="flex flex-col items-center gap-[2.6cqmin]">
                    <Medallion
                        model={model}
                        size="size-[38cqmin]"
                        clockClass="text-[10cqmin]"
                    />
                    <NextUp
                        model={model}
                        text={text}
                        className="justify-center text-[3.2cqmin]"
                    />
                    <ExtraTimes
                        model={model}
                        text={text}
                        className="justify-center text-[2.2cqmin]"
                    />
                </section>
                <Table
                    {...props}
                    rowClass="px-[2cqmin] py-[0.9cqmin]"
                    timeClass="text-[4.8cqmin]"
                    nameClass="text-[3cqmin] leading-tight font-semibold"
                    secondClass="text-[1.7cqmin] leading-tight"
                />
            </main>
            <section
                className={cn(
                    cartouche,
                    'flex h-[21cqmin] shrink-0 flex-col px-[7cqmin] py-[2cqmin]',
                )}
            >
                <RotationPanel
                    slide={slide}
                    text={text}
                    period={model.period}
                    size={2.6}
                    hafsReady={hafsReady}
                    className="h-full"
                />
            </section>
        </div>
    );
}

function Portrait(props: ThemeProps) {
    const { model, text, payload, slide, hafsReady } = props;

    return (
        <div className="relative flex size-full flex-col items-stretch gap-[2.4cqmin] px-[7cqmin] py-[6cqmin]">
            <MosqueTitle
                payload={payload}
                className="justify-center text-[4.2cqmin]"
                logoClass="size-[7cqmin]"
            />
            <div className="flex flex-col items-center gap-[2cqmin]">
                <Medallion
                    model={model}
                    size="size-[46cqmin]"
                    clockClass="text-[12cqmin]"
                />
                <Dates
                    model={model}
                    text={text}
                    className="items-center text-[3.6cqmin]"
                />
                <NextUp
                    model={model}
                    text={text}
                    className="justify-center text-[4cqmin]"
                />
            </div>
            <Table
                {...props}
                rowClass="px-[2.6cqmin] py-[0.9cqmin]"
                timeClass="text-[5.6cqmin]"
                nameClass="text-[4.2cqmin] leading-tight font-semibold"
                secondClass="text-[2.2cqmin] leading-tight"
            />
            <ExtraTimes
                model={model}
                text={text}
                className="justify-center text-[3.2cqmin]"
            />
            <section
                className={cn(
                    cartouche,
                    'flex min-h-0 flex-1 flex-col rounded-[6cqmin] px-[6cqmin] py-[3cqmin]',
                )}
            >
                <RotationPanel
                    slide={slide}
                    text={text}
                    period={model.period}
                    size={4}
                    hafsReady={hafsReady}
                    className="h-full"
                />
            </section>
        </div>
    );
}
