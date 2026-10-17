import { CalendarOff } from 'lucide-react';
import type { ScreenModel } from '../lib/model';
import type { ScreenText } from '../lib/text';
import type { DisplayPayload } from '../types';
import { BigClock, Dates, Lang, MosqueTitle } from './parts';

/**
 * A mosque without published times for today: the clock and the date, and a
 * plain notice — times are never estimated.
 */
export function NoTimes({
    model,
    text,
    payload,
    layout,
}: {
    model: ScreenModel;
    text: ScreenText;
    payload: DisplayPayload;
    layout: 'landscape' | 'portrait';
}) {
    return (
        <div
            className="flex size-full flex-col items-center justify-center gap-[3cqmin] p-[6cqmin] text-center"
            style={{
                background:
                    'radial-gradient(120% 90% at 50% 0%, #0f4a3b 0%, #08342a 45%, #04211b 100%)',
            }}
        >
            <MosqueTitle
                payload={payload}
                className={
                    layout === 'landscape'
                        ? 'text-[3.6cqmin]'
                        : 'text-[4.6cqmin]'
                }
                logoClass="size-[7cqmin]"
            />
            <BigClock
                model={model}
                className={
                    layout === 'landscape' ? 'text-[18cqmin]' : 'text-[24cqmin]'
                }
            />
            <Dates
                model={model}
                text={text}
                className="items-center text-[3.2cqmin]"
            />
            <p className="mt-[2cqmin] flex max-w-[70cqw] items-center gap-[1.4cqmin] rounded-[2cqmin] bg-(--d-panel) px-[3cqmin] py-[2cqmin] text-[2.8cqmin] text-(--d-muted) ring-1 ring-(--d-line)">
                <CalendarOff
                    className="size-[3.4cqmin] shrink-0 text-(--d-accent)"
                    aria-hidden
                />
                <Lang language={text.primary}>{text.t('no_times')}</Lang>
            </p>
        </div>
    );
}
