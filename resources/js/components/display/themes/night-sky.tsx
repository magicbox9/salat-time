import { cn } from '@/lib/utils';
import { RotationPanel } from '../screen/rotation-panel';
import {
    BigClock,
    Dates,
    Dual,
    MosqueTitle,
    NextUp,
    Time,
} from '../screen/parts';
import type { ThemeProps } from './shared';
import { ExtraTimes, IqamaTime, TomorrowTag } from './shared';
import { SkyArc, SkyBackdrop } from './sky-layers';

/**
 * "Night sky": the Mac app's living sky — the colours of the mosque's sky at
 * this minute, stars after dusk, the sun or the moon on its arc and the
 * silhouette of a mosque — with the times on glass.
 */
export function NightSkyTheme(props: ThemeProps) {
    const { model, layout, text, payload } = props;

    return (
        <div className="relative size-full overflow-hidden">
            <SkyBackdrop model={model} />
            <SkyArc
                model={model}
                rtl={text.primary === 'ar'}
                southern={payload.mosque.lat < 0}
                className={
                    layout === 'landscape'
                        ? 'top-[4%] h-[46%]'
                        : 'top-[3%] h-[24%]'
                }
            />
            {layout === 'landscape' ? (
                <Landscape {...props} />
            ) : (
                <Portrait {...props} />
            )}
        </div>
    );
}

const glass =
    'rounded-[2.4cqmin] bg-(--d-panel) ring-1 ring-(--d-line) backdrop-blur-md';

function Landscape({ model, text, payload, slide, hafsReady }: ThemeProps) {
    return (
        <div className="relative flex size-full flex-col p-[3.4cqmin] [text-shadow:0_0.2cqmin_1.2cqmin_rgb(0_0_0/0.35)]">
            <header className="flex items-start justify-between gap-[4cqmin]">
                <MosqueTitle
                    payload={payload}
                    className="text-[3cqmin]"
                    logoClass="size-[5.4cqmin]"
                />
                <Dates
                    model={model}
                    text={text}
                    className="shrink-0 items-end text-end text-[2.6cqmin]"
                />
            </header>

            <section className="mt-[8cqmin] flex flex-col items-center gap-[1.6cqmin] text-center">
                <BigClock model={model} className="text-[17cqmin] font-light" />
                <NextUp
                    model={model}
                    text={text}
                    className="justify-center text-[3.4cqmin]"
                />
            </section>

            <div className="mt-auto grid grid-cols-[1.5fr_1fr] items-end gap-[2.4cqmin]">
                <div
                    className={cn(
                        glass,
                        'grid auto-cols-fr grid-flow-col p-[1.2cqmin]',
                    )}
                >
                    {model.rows.map((row) => {
                        const name = text.prayer(row.prayer);

                        return (
                            <div
                                key={row.prayer}
                                className={cn(
                                    'flex flex-col items-center gap-[0.6cqmin] rounded-[1.8cqmin] px-[0.6cqmin] py-[1.6cqmin] text-center transition-colors duration-700',
                                    row.state === 'next' &&
                                        'bg-white/12 ring-1 ring-(--d-accent)',
                                    row.state === 'next' &&
                                        model.phase.kind === 'approaching' &&
                                        'd-glow',
                                    row.state === 'current' &&
                                        'bg-(--d-accent) text-(--d-accent-ink) [text-shadow:none]',
                                    row.state === 'passed' && 'opacity-55',
                                )}
                            >
                                <Dual
                                    text={text}
                                    main={name.main}
                                    second={name.second}
                                    className="items-center"
                                    mainClass="text-[2.6cqmin] font-semibold"
                                    secondClass="text-[1.6cqmin]"
                                />
                                <Time
                                    value={row.time}
                                    model={model}
                                    className="text-[5.6cqmin] leading-none font-semibold"
                                />
                                <span className="flex h-[2.6cqmin] items-center text-[1.9cqmin]">
                                    <TomorrowTag
                                        show={row.tomorrow}
                                        text={text}
                                    />
                                    {!row.tomorrow && (
                                        <IqamaTime
                                            value={row.iqama}
                                            model={model}
                                            text={text}
                                        />
                                    )}
                                </span>
                            </div>
                        );
                    })}
                </div>
                <div className="flex min-h-0 flex-col gap-[1.6cqmin]">
                    <ExtraTimes
                        model={model}
                        text={text}
                        className="justify-end text-[2.2cqmin]"
                        itemClass="backdrop-blur-md"
                    />
                    <section
                        className={cn(
                            glass,
                            'flex h-[34cqmin] flex-col p-[2.4cqmin]',
                        )}
                    >
                        <RotationPanel
                            slide={slide}
                            text={text}
                            period={model.period}
                            size={2.8}
                            hafsReady={hafsReady}
                            className="h-full"
                        />
                    </section>
                </div>
            </div>
        </div>
    );
}

function Portrait({ model, text, payload, slide, hafsReady }: ThemeProps) {
    return (
        <div className="relative flex size-full flex-col gap-[2.4cqmin] p-[5cqmin] [text-shadow:0_0.2cqmin_1.2cqmin_rgb(0_0_0/0.35)]">
            <MosqueTitle
                payload={payload}
                className="text-[4cqmin]"
                logoClass="size-[7cqmin]"
            />

            <section className="mt-[13cqmin] flex flex-col items-center gap-[1.2cqmin] text-center">
                <BigClock model={model} className="text-[20cqmin] font-light" />
                <Dates
                    model={model}
                    text={text}
                    className="items-center text-[3.6cqmin]"
                />
                <NextUp
                    model={model}
                    text={text}
                    className="justify-center text-[4.2cqmin]"
                />
            </section>

            <ul className={cn(glass, 'flex flex-col p-[1.6cqmin]')}>
                {model.rows.map((row) => {
                    const name = text.prayer(row.prayer);

                    return (
                        <li
                            key={row.prayer}
                            className={cn(
                                'flex items-center gap-[3cqmin] rounded-[1.8cqmin] px-[2.6cqmin] py-[0.9cqmin] transition-colors duration-700',
                                row.state === 'next' &&
                                    'bg-white/12 ring-1 ring-(--d-accent)',
                                row.state === 'next' &&
                                    model.phase.kind === 'approaching' &&
                                    'd-glow',
                                row.state === 'current' &&
                                    'bg-(--d-accent) text-(--d-accent-ink) [text-shadow:none]',
                                row.state === 'passed' && 'opacity-55',
                            )}
                        >
                            <Dual
                                text={text}
                                main={name.main}
                                second={name.second}
                                className="flex-1"
                                mainClass="text-[4.2cqmin] leading-tight font-semibold"
                                secondClass="text-[2.2cqmin] leading-tight"
                            />
                            <TomorrowTag show={row.tomorrow} text={text} />
                            <Time
                                value={row.time}
                                model={model}
                                className="text-[6.4cqmin] leading-none font-semibold"
                            />
                            {model.settings.show_iqama && (
                                <Time
                                    value={row.tomorrow ? null : row.iqama}
                                    model={model}
                                    className="w-[14cqmin] text-center text-[4cqmin] opacity-75"
                                />
                            )}
                        </li>
                    );
                })}
            </ul>

            <ExtraTimes
                model={model}
                text={text}
                className="justify-center text-[3.2cqmin]"
                itemClass="backdrop-blur-md"
            />

            <section
                className={cn(glass, 'flex min-h-0 flex-1 flex-col p-[4cqmin]')}
            >
                <RotationPanel
                    slide={slide}
                    text={text}
                    period={model.period}
                    size={4.2}
                    hafsReady={hafsReady}
                    className="h-full"
                />
            </section>
        </div>
    );
}
