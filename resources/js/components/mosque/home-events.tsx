import { Link, usePage } from '@inertiajs/react';
import { CalendarDays } from 'lucide-react';
import { useT } from '@/lib/i18n';
import type { PostCardData } from './site-types';

/** Day and month of an event, in the mosque's time zone. */
function parts(iso: string, locale: string, timeZone: string) {
    const date = new Date(iso);
    const fmt = (options: Intl.DateTimeFormatOptions) =>
        new Intl.DateTimeFormat(locale === 'ar' ? 'ar-u-nu-latn' : locale, {
            ...options,
            timeZone,
        }).format(date);

    return {
        day: fmt({ day: 'numeric' }),
        month: fmt({ month: 'short' }),
        when: fmt({ weekday: 'long', hour: '2-digit', minute: '2-digit' }),
    };
}

/** What is coming up at the mosque: lessons, gatherings, iftars… */
export function HomeEvents({
    events,
    timezone,
}: {
    events: PostCardData[];
    timezone: string;
}) {
    const t = useT();
    const { locale } = usePage().props;

    if (events.length === 0) {
        return null;
    }

    return (
        <section
            aria-labelledby="mosque-events"
            className="rounded-2xl border bg-card p-5 shadow-xs"
        >
            <h2
                id="mosque-events"
                className="flex items-center gap-2 font-semibold"
            >
                <CalendarDays
                    className="size-4 text-[var(--site-accent-ink)]"
                    aria-hidden
                />
                {t('mosquesite.upcoming_events')}
            </h2>
            <ul className="mt-3 space-y-1">
                {events.map((event) => {
                    const when = parts(
                        event.event_starts_at ?? '',
                        locale,
                        timezone,
                    );

                    return (
                        <li key={event.id}>
                            <Link
                                href={event.url}
                                className="group flex items-center gap-3 rounded-xl p-2 transition-colors outline-none hover:bg-accent/60 focus-visible:ring-2 focus-visible:ring-[var(--site-accent)]/50"
                            >
                                <span className="flex size-12 shrink-0 flex-col items-center justify-center rounded-xl bg-[var(--site-accent)]/10 leading-none">
                                    <span
                                        className="text-lg font-semibold tabular-nums"
                                        dir="ltr"
                                    >
                                        {when.day}
                                    </span>
                                    <span className="mt-0.5 text-[11px] text-muted-foreground uppercase">
                                        {when.month}
                                    </span>
                                </span>
                                <span className="min-w-0">
                                    <span
                                        dir="auto"
                                        className="line-clamp-2 text-sm font-medium group-hover:underline group-hover:underline-offset-4"
                                    >
                                        {event.title}
                                    </span>
                                    <span className="block text-xs text-muted-foreground first-letter:uppercase">
                                        {when.when}
                                    </span>
                                </span>
                            </Link>
                        </li>
                    );
                })}
            </ul>
        </section>
    );
}
