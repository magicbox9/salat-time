import { Link } from '@inertiajs/react';
import { ArrowUpRight, BookOpenText, MoonStar, Sunrise } from 'lucide-react';
import { useT } from '@/lib/i18n';
import type { DayView } from './types';

type Suggestion = { key: 'morning' | 'evening' | 'sleep'; href: string };

/**
 * The adhkar that fit this moment of the mosque's day: the morning adhkar
 * from Fajr until Dhuhr, the evening adhkar from Asr until Isha, the adhkar
 * before sleep at night (texts live on /adhkar, from the verified library).
 */
export function suggestAdhkar(view: DayView | null): Suggestion | null {
    if (!view) {
        return null;
    }

    const at = (prayer: string) =>
        view.rows.find((row) => row.prayer === prayer)?.minutes ?? null;
    const now = view.nowMinutes;
    const [fajr, dhuhr, asr, isha] = [
        at('fajr'),
        at('dhuhr'),
        at('asr'),
        at('isha'),
    ];

    if (fajr === null || dhuhr === null || asr === null || isha === null) {
        return null;
    }

    if (now >= fajr && now < dhuhr) {
        return { key: 'morning', href: '/adhkar/morning' };
    }

    if (now >= asr && now < isha) {
        return { key: 'evening', href: '/adhkar/evening' };
    }

    if (now >= isha || now < fajr) {
        return { key: 'sleep', href: '/adhkar/sleep' };
    }

    return null;
}

const ICON = { morning: Sunrise, evening: MoonStar, sleep: MoonStar };

export function AdhkarSuggestion({ view }: { view: DayView | null }) {
    const t = useT();
    const suggestion = suggestAdhkar(view);
    const Icon = suggestion ? ICON[suggestion.key] : BookOpenText;

    return (
        <section
            aria-labelledby="hub-adhkar"
            className="flex flex-col rounded-2xl border bg-gradient-to-br from-card to-[color-mix(in_oklab,var(--gold)_8%,var(--card))] p-5"
        >
            <h2
                id="hub-adhkar"
                className="flex items-center gap-2 font-semibold"
            >
                <Icon className="size-4 text-gold" aria-hidden />
                {suggestion
                    ? t(`hub.adhkar_${suggestion.key}`)
                    : t('hub.adhkar_title')}
            </h2>
            <p className="mt-2 flex-1 text-sm text-muted-foreground">
                {suggestion
                    ? t(`hub.adhkar_${suggestion.key}_text`)
                    : t('hub.adhkar_text')}
            </p>
            <div className="mt-4 flex flex-wrap gap-x-4 gap-y-2 text-sm">
                <Link
                    href={suggestion?.href ?? '/adhkar'}
                    className="inline-flex items-center gap-1 font-medium text-primary hover:underline"
                >
                    {suggestion ? t('hub.adhkar_open') : t('hub.adhkar_all')}
                    <ArrowUpRight
                        className="size-3.5 rtl:-scale-x-100"
                        aria-hidden
                    />
                </Link>
                <Link
                    href="/quran"
                    className="inline-flex items-center gap-1 text-muted-foreground hover:text-foreground hover:underline"
                >
                    {t('hub.quran_open')}
                </Link>
            </div>
        </section>
    );
}
