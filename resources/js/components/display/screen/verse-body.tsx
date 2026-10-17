import { cn } from '@/lib/utils';
import { fit, fitSize, withoutAyahMark } from '../lib/rotation';
import type { ScreenText } from '../lib/text';
import { arabicDigits } from '../lib/zone';
import type { Verse } from '../types';

/**
 * A verse as the corpus publishes it (KFGQPC face, its own ayah marks) with
 * the QuranEnc meaning and its attribution. Without the face, the ayah mark
 * is left out and the number is drawn apart — never stored.
 */
export function VerseBody({
    verse,
    text,
    size,
    hafsReady,
    compact,
}: {
    verse: Verse;
    text: ScreenText;
    size: number;
    hafsReady: boolean;
    compact: boolean;
}) {
    const arabic = verse.ayat.map((a) => a.text).join(' ');
    const translation = text.translation
        ? verse.translations[text.translation]
        : undefined;

    return (
        <>
            <p
                lang="ar"
                dir="rtl"
                className={cn(
                    'leading-[2.05]',
                    hafsReady ? 'font-quran' : 'font-adhkar',
                    compact && 'line-clamp-2',
                )}
                style={fit(fitSize(arabic, size * 1.25, 110))}
            >
                {hafsReady
                    ? arabic
                    : verse.ayat.map((a) => (
                          <span key={a.ayah}>
                              {withoutAyahMark(a.text)}{' '}
                              <span className="mx-[0.2em] inline-flex size-[1.25em] items-center justify-center rounded-full border border-(--d-accent) align-middle text-[0.5em] text-(--d-accent)">
                                  {arabicDigits(a.ayah)}
                              </span>{' '}
                          </span>
                      ))}
            </p>
            {translation && !compact && (
                <div
                    lang={text.translation ?? undefined}
                    dir="ltr"
                    className="flex flex-col gap-[0.6cqmin]"
                >
                    <p
                        className="leading-relaxed text-(--d-fg)/90"
                        style={fit(
                            fitSize(translation.text, size * 0.62, 200, 0.6),
                        )}
                    >
                        {translation.text}
                    </p>
                    <p className="text-[1.3cqmin] text-(--d-muted) opacity-80">
                        {translation.title} · v{translation.version} ·
                        quranenc.com
                    </p>
                </div>
            )}
        </>
    );
}
