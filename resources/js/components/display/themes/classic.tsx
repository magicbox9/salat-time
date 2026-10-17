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
import type { ThemeProps } from './shared';
import {
    BackgroundImage,
    ExtraTimes,
    FacetBackdrop,
    IqamaTime,
    TomorrowTag,
} from './shared';

/**
 * "Classic": the layout people know from mosque screens — a big clock with
 * seconds, both dates, the five prayers with adhan and iqama, Sunrise and
 * Jumu'a, the next prayer and its countdown, and a rotating panel — drawn in
 * Salat Time's deep green and gold.
 */
export function ClassicTheme(props: ThemeProps) {
    const { payload, layout } = props;

    return (
        <div
            className="relative size-full overflow-hidden"
            style={{
                background:
                    'radial-gradient(120% 90% at 20% 0%, #0f4a3b 0%, #08342a 45%, #04211b 100%)',
            }}
        >
            <FacetBackdrop />
            <BackgroundImage url={payload.background_url} />
            {layout === 'landscape' ? (
                <Landscape {...props} />
            ) : (
                <Portrait {...props} />
            )}
        </div>
    );
}

function Landscape({ model, text, payload, slide, hafsReady }: ThemeProps) {
    return (
        <div className="relative flex size-full flex-col gap-[2.6cqmin] p-[3.4cqmin]">
            <header className="flex items-start justify-between gap-[4cqmin]">
                <MosqueTitle
                    payload={payload}
                    className="text-[3.4cqmin]"
                    logoClass="size-[6cqmin]"
                />
                <Dates
                    model={model}
                    text={text}
                    className="shrink-0 items-end text-end text-[2.7cqmin]"
                />
            </header>

            <main className="grid min-h-0 flex-1 grid-cols-[1fr_1.2fr] gap-[3.4cqmin]">
                <section className="flex min-w-0 flex-col justify-center gap-[2.2cqmin]">
                    <BigClock
                        model={model}
                        className="text-[length:min(20cqmin,12.5cqw)]"
                    />
                    <NextUp
                        model={model}
                        text={text}
                        className="text-[3.7cqmin]"
                    />
                    <ExtraTimes
                        model={model}
                        text={text}
                        className="text-[2.5cqmin]"
                    />
                </section>
                <section className="flex min-h-0 flex-col rounded-[2.4cqmin] bg-(--d-panel) p-[3cqmin] ring-1 ring-(--d-line) backdrop-blur-sm">
                    <RotationPanel
                        slide={slide}
                        text={text}
                        period={model.period}
                        size={3.6}
                        hafsReady={hafsReady}
                        className="h-full"
                    />
                </section>
            </main>

            <footer className="grid auto-cols-fr grid-flow-col gap-[1.6cqmin]">
                {model.rows.map((row) => (
                    <Card
                        key={row.prayer}
                        row={row}
                        {...{
                            model,
                            text,
                            payload,
                            slide,
                            hafsReady,
                            layout: 'landscape',
                        }}
                    />
                ))}
            </footer>
        </div>
    );
}

function Card({ row, model, text }: ThemeProps & { row: Row }) {
    const name = text.prayer(row.prayer);

    return (
        <div
            className={cn(
                'flex flex-col items-center gap-[0.8cqmin] rounded-[2cqmin] px-[1.4cqmin] py-[2cqmin] text-center ring-1 transition-[background-color,opacity,box-shadow] duration-700',
                row.state === 'next' &&
                    'bg-[color-mix(in_oklab,var(--d-accent)_16%,transparent)] ring-(--d-accent)',
                row.state === 'next' &&
                    model.phase.kind === 'approaching' &&
                    'd-glow',
                row.state === 'current' &&
                    'bg-(--d-accent) text-(--d-accent-ink) ring-(--d-accent)',
                (row.state === 'upcoming' || row.state === 'passed') &&
                    'bg-(--d-panel) ring-(--d-line)',
                row.state === 'passed' && 'opacity-55',
            )}
        >
            <Dual
                text={text}
                main={name.main}
                second={name.second}
                className="items-center"
                mainClass="text-[3.2cqmin] font-semibold"
                secondClass={cn(
                    'text-[1.9cqmin]',
                    row.state === 'current' && 'text-(--d-accent-ink)/75',
                )}
            />
            <Time
                value={row.time}
                model={model}
                className="text-[7.4cqmin] leading-none font-semibold tracking-tight"
            />
            <span className="flex h-[3cqmin] items-center gap-[1cqmin] text-[2.3cqmin]">
                <TomorrowTag show={row.tomorrow} text={text} />
                {!row.tomorrow && (
                    <IqamaTime
                        value={row.iqama}
                        model={model}
                        text={text}
                        className={cn(
                            row.state === 'current' &&
                                '[&_*]:text-(--d-accent-ink)',
                        )}
                    />
                )}
            </span>
        </div>
    );
}

function Portrait({ model, text, payload, slide, hafsReady }: ThemeProps) {
    return (
        <div className="relative flex size-full flex-col gap-[2.4cqmin] p-[5cqmin]">
            <header className="flex items-center justify-between gap-[3cqmin]">
                <MosqueTitle
                    payload={payload}
                    className="text-[4.4cqmin]"
                    logoClass="size-[8cqmin]"
                />
            </header>

            <section className="flex flex-col items-center gap-[1.6cqmin] text-center">
                <BigClock model={model} className="text-[22cqmin]" />
                <Dates
                    model={model}
                    text={text}
                    className="items-center text-[3.8cqmin]"
                />
                <NextUp
                    model={model}
                    text={text}
                    className="justify-center text-[4.4cqmin]"
                />
            </section>

            <ul className="flex flex-col gap-[1.1cqmin]">
                {model.settings.show_iqama && (
                    <li
                        className="-mb-[0.6cqmin] flex items-center gap-[3cqmin] px-[3cqmin] text-[2.4cqmin] text-(--d-muted)"
                        aria-hidden
                    >
                        <span className="flex-1" />
                        <Lang
                            language={text.primary}
                            className="w-[27cqmin] text-center"
                        >
                            {text.t('adhan')}
                        </Lang>
                        <Lang
                            language={text.primary}
                            className="w-[14cqmin] text-center"
                        >
                            {text.t('iqama')}
                        </Lang>
                    </li>
                )}
                {model.rows.map((row) => {
                    const name = text.prayer(row.prayer);

                    return (
                        <li
                            key={row.prayer}
                            className={cn(
                                'flex items-center gap-[3cqmin] rounded-[2.2cqmin] px-[3cqmin] py-[1.1cqmin] ring-1 transition-colors duration-700',
                                row.state === 'next' &&
                                    'bg-[color-mix(in_oklab,var(--d-accent)_16%,transparent)] ring-(--d-accent)',
                                row.state === 'next' &&
                                    model.phase.kind === 'approaching' &&
                                    'd-glow',
                                row.state === 'current' &&
                                    'bg-(--d-accent) text-(--d-accent-ink) ring-(--d-accent)',
                                (row.state === 'upcoming' ||
                                    row.state === 'passed') &&
                                    'bg-(--d-panel) ring-(--d-line)',
                                row.state === 'passed' && 'opacity-55',
                            )}
                        >
                            <Dual
                                text={text}
                                main={name.main}
                                second={name.second}
                                className="flex-1"
                                mainClass="text-[4.6cqmin] leading-tight font-semibold"
                                secondClass="text-[2.4cqmin] leading-tight"
                            />
                            <span className="flex w-[27cqmin] items-center justify-center gap-[1.4cqmin]">
                                <TomorrowTag show={row.tomorrow} text={text} />
                                <Time
                                    value={row.time}
                                    model={model}
                                    className="text-[7cqmin] leading-none font-semibold"
                                />
                            </span>
                            {model.settings.show_iqama && (
                                <Time
                                    value={row.tomorrow ? null : row.iqama}
                                    model={model}
                                    className="w-[14cqmin] text-center text-[4.4cqmin] opacity-75"
                                />
                            )}
                        </li>
                    );
                })}
            </ul>

            <ExtraTimes
                model={model}
                text={text}
                className="justify-center text-[3.4cqmin]"
            />

            <section className="flex min-h-0 flex-1 flex-col rounded-[2.4cqmin] bg-(--d-panel) p-[4cqmin] ring-1 ring-(--d-line) backdrop-blur-sm">
                <RotationPanel
                    slide={slide}
                    text={text}
                    period={model.period}
                    size={4.4}
                    hafsReady={hafsReady}
                    className="h-full"
                />
            </section>
        </div>
    );
}
