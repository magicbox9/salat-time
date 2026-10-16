import { Link, usePage } from '@inertiajs/react';
import { BadgeCheck, CalendarX2, ChevronRight } from 'lucide-react';
import { intlLocale, useT } from '@/lib/i18n';
import type { MosqueSummary } from '@/types/mosque';
import type { MosqueDetails } from './types';

type Props = { mosque: MosqueDetails; nearby: MosqueSummary[] };

/** No published calendar: say so plainly (times are never guessed) and point to neighbours. */
export function NoTimes({ mosque, nearby }: Props) {
    const t = useT();
    const { locale } = usePage().props;
    const km = new Intl.NumberFormat(intlLocale(locale), {
        maximumFractionDigits: 1,
    });

    return (
        <section
            aria-labelledby="no-times"
            className="rounded-2xl border bg-card p-5 shadow-xs sm:p-6"
        >
            <div className="flex items-start gap-3">
                <span className="rounded-xl bg-muted p-2.5">
                    <CalendarX2 className="size-5 text-muted-foreground" />
                </span>
                <div>
                    <h2 id="no-times" className="text-lg font-semibold">
                        {t('mosque.no_times_title')}
                    </h2>
                    <p className="mt-1 text-sm text-muted-foreground">
                        {t('mosque.no_times_body', { name: mosque.name })}
                    </p>
                </div>
            </div>

            {nearby.length > 0 && (
                <div className="mt-5">
                    <h3 className="text-sm font-medium">
                        {t('mosque.nearby_with_times')}
                    </h3>
                    <ul className="mt-2 divide-y rounded-xl border">
                        {nearby.map((other) => (
                            <li key={other.id}>
                                <Link
                                    href={`/mosques/${other.slug}`}
                                    className="flex items-center gap-3 px-4 py-3 transition-colors hover:bg-accent/60"
                                >
                                    <span className="min-w-0 flex-1">
                                        <span className="flex items-center gap-1.5 font-medium">
                                            <span className="truncate">
                                                {other.name}
                                            </span>
                                            {other.verified && (
                                                <BadgeCheck className="size-4 shrink-0 text-gold" />
                                            )}
                                        </span>
                                        <span className="block truncate text-xs text-muted-foreground">
                                            {[other.city, other.postcode]
                                                .filter(Boolean)
                                                .join(' · ')}
                                        </span>
                                    </span>
                                    {other.distance_m !== null && (
                                        <span
                                            className="shrink-0 text-xs text-muted-foreground tabular-nums"
                                            dir="ltr"
                                        >
                                            {other.distance_m >= 1000
                                                ? t('site.km_away', {
                                                      distance: km.format(
                                                          other.distance_m /
                                                              1000,
                                                      ),
                                                  })
                                                : t('site.m_away', {
                                                      distance:
                                                          other.distance_m,
                                                  })}
                                        </span>
                                    )}
                                    <ChevronRight className="size-4 shrink-0 text-muted-foreground rtl:rotate-180" />
                                </Link>
                            </li>
                        ))}
                    </ul>
                </div>
            )}
        </section>
    );
}
