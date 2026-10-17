import type { ScreenModel } from '../lib/model';
import type { ScreenText } from '../lib/text';
import type { AfterPrayerDhikr } from '../types';
import { Layer } from './layer';
import { Lang, Ltr } from './parts';

/**
 * The adhkar said after the prayer (Hisn al-Muslim, unchanged), one after
 * the other through the slide's duration.
 */
export function AfterPrayer({
    model,
    text,
    items,
}: {
    model: ScreenModel;
    text: ScreenText;
    items: AfterPrayerDhikr[];
}) {
    const index = Math.min(
        items.length - 1,
        Math.floor(model.phase.progress * items.length),
    );
    const item = items[index];
    const showMeaning =
        model.settings.languages.includes('en') && item.meaning_en;
    const size =
        item.arabic.length > 260 ? 3.4 : item.arabic.length > 160 ? 4.2 : 5.2;

    return (
        <Layer
            style={{
                background:
                    'linear-gradient(180deg, var(--d-bg), color-mix(in oklab, var(--d-accent) 8%, var(--d-bg)))',
            }}
        >
            <div className="flex flex-col items-center gap-[0.6cqmin]">
                <Lang
                    language={text.primary}
                    className="text-[3.4cqmin] font-semibold text-(--d-accent)"
                >
                    {text.t('after_prayer')}
                </Lang>
                {text.t2('after_prayer') && (
                    <Lang
                        language={text.secondary ?? text.primary}
                        className="text-[2.2cqmin] text-(--d-muted)"
                    >
                        {text.t2('after_prayer')}
                    </Lang>
                )}
            </div>
            <div
                key={item.id}
                className="d-fade-up mt-[4cqmin] flex max-w-[88cqw] flex-col items-center gap-[2.4cqmin]"
            >
                <p
                    lang="ar"
                    dir="rtl"
                    className="font-adhkar leading-[1.9]"
                    style={{ fontSize: `${size}cqmin` }}
                >
                    {item.arabic}
                </p>
                {item.count > 1 && (
                    <Ltr className="rounded-full border border-(--d-line) px-[1.6cqmin] py-[0.4cqmin] text-[2.4cqmin] text-(--d-accent)">
                        ×{item.count}
                    </Ltr>
                )}
                {showMeaning && (
                    <p
                        lang="en"
                        dir="ltr"
                        className="line-clamp-4 max-w-[80cqw] text-[2.1cqmin] leading-relaxed text-(--d-muted)"
                    >
                        {item.meaning_en}
                    </p>
                )}
            </div>
            <p className="absolute bottom-[3cqmin] flex items-center gap-[0.8cqmin] text-[1.4cqmin] text-(--d-muted) opacity-70">
                <Lang language={text.primary}>{text.t('source_hisn')}</Lang>
                {text.secondary &&
                    text.t2('source_hisn') !== text.t('source_hisn') && (
                        <>
                            <span aria-hidden>·</span>
                            <Lang language={text.secondary}>
                                {text.t2('source_hisn')}
                            </Lang>
                        </>
                    )}
            </p>
        </Layer>
    );
}
