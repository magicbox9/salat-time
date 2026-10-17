import { Link, usePage } from '@inertiajs/react';
import { CalendarX2, Home, MapPin } from 'lucide-react';
import { useState } from 'react';
import { chooseMosque } from '@/components/discover/choose-mosque';
import { formatDistance, placeLine } from '@/components/discover/format';
import { NextPrayerLine } from '@/components/discover/next-prayer-line';
import type { MosqueCard } from '@/components/discover/types';
import { Button } from '@/components/ui/button';
import { useT } from '@/lib/i18n';

/**
 * The chosen mosque publishes no times here (or none complete for today):
 * say so kindly (a gap is never filled with a guess) and offer the closest
 * mosques that do.
 */
export function NoTimes({
    mosqueName,
    publishes,
    nearby,
}: {
    mosqueName: string;
    /** It has a published calendar, but today's times are missing or incomplete. */
    publishes: boolean;
    nearby: MosqueCard[];
}) {
    const t = useT();
    const prefix = publishes ? 'hub.no_times_today' : 'hub.no_times';

    return (
        <section
            aria-labelledby="hub-no-times"
            className="rounded-2xl border bg-card p-5 sm:p-6"
        >
            <h2
                id="hub-no-times"
                className="flex items-center gap-2 text-lg font-semibold"
            >
                <CalendarX2 className="size-5 text-gold" aria-hidden />
                {t(`${prefix}_title`)}
            </h2>
            <p className="mt-2 max-w-2xl text-sm text-muted-foreground">
                {t(
                    nearby.length > 0
                        ? `${prefix}_text`
                        : `${prefix}_text_alone`,
                    { name: mosqueName },
                )}
            </p>

            {nearby.length > 0 ? (
                <NearbyPublishing nearby={nearby} />
            ) : (
                <Button asChild variant="outline" className="mt-5">
                    <Link href="/explore">{t('hub.action_change')}</Link>
                </Button>
            )}
        </section>
    );
}

/** The closest mosques that publish their own times, each with its next prayer and "make it my mosque". */
export function NearbyPublishing({ nearby }: { nearby: MosqueCard[] }) {
    const t = useT();
    const { locale } = usePage().props;
    const [busy, setBusy] = useState(false);
    const choose = (slug: string) => chooseMosque(slug, t, setBusy);

    if (nearby.length === 0) {
        return null;
    }

    return (
        <>
            <h3 className="mt-6 text-sm font-semibold">
                {t('hub.no_times_nearby')}
            </h3>
            <ul className="mt-3 grid gap-3 sm:grid-cols-2">
                {nearby.map((mosque) => {
                    const distance = formatDistance(
                        mosque.distance_m,
                        t,
                        locale,
                    );

                    return (
                        <li
                            key={mosque.id}
                            className="flex flex-col rounded-xl border bg-card p-4"
                        >
                            <Link
                                href={`/mosques/${encodeURIComponent(mosque.slug)}`}
                                className="font-medium hover:underline"
                            >
                                <bdi>{mosque.name}</bdi>
                            </Link>
                            <p className="mt-0.5 flex items-start gap-1 text-xs text-muted-foreground">
                                <MapPin
                                    className="mt-0.5 size-3 shrink-0"
                                    aria-hidden
                                />
                                <span dir="auto">
                                    {placeLine(mosque)}
                                    {distance && (
                                        <>
                                            {' '}
                                            ·{' '}
                                            <span className="tabular-nums">
                                                {distance}
                                            </span>
                                        </>
                                    )}
                                </span>
                            </p>
                            <NextPrayerLine
                                today={mosque.today}
                                tomorrow={mosque.tomorrow}
                                timezone={mosque.timezone}
                                className="mt-3"
                            />
                            <Button
                                size="sm"
                                variant="outline"
                                className="mt-3 self-start"
                                disabled={busy}
                                onClick={() => choose(mosque.slug)}
                            >
                                <Home />
                                {t('discover.make_my_mosque')}
                            </Button>
                        </li>
                    );
                })}
            </ul>
        </>
    );
}
