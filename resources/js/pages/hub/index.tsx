import { Head, Link } from '@inertiajs/react';
import { ShieldCheck, SlidersHorizontal } from 'lucide-react';
import { useState } from 'react';
import { dateInZone } from '@/components/discover/format';
import { MosqueCampaigns } from '@/components/fundraising/mosque-campaigns';
import { AccountCard } from '@/components/hub/account-card';
import { AdhanOverlay } from '@/components/hub/adhan/adhan-overlay';
import { AdhanPill } from '@/components/hub/adhan/adhan-pill';
import { SoundPrompt } from '@/components/hub/adhan/sound-prompt';
import { useAdhan } from '@/components/hub/adhan/use-adhan';
import { useAdhanCatalog } from '@/components/hub/adhan/use-adhan-catalog';
import { AdhkarSuggestion } from '@/components/hub/adhkar-suggestion';
import { CustomiseSheet } from '@/components/hub/customise/customise-sheet';
import { STYLE_ICON } from '@/components/hub/customise/style-picker';
import { buildDayView } from '@/components/hub/day';
import { HubHero } from '@/components/hub/hub-hero';
import { LatestPosts } from '@/components/hub/latest-posts';
import { NearbyPublishing, NoTimes } from '@/components/hub/no-times';
import { prayerDay } from '@/components/hub/prayer-day';
import { QuickActions } from '@/components/hub/quick-actions';
import { TimesDisplay } from '@/components/hub/styles/times-display';
import { TrackerCheckIn } from '@/components/hub/tracker-check-in';
import {
    CalculatedNotice,
    isCalculated,
} from '@/components/prayer/calculated-notice';
import type { HubPageProps } from '@/components/hub/types';
import { useHubPreferences } from '@/components/hub/use-hub-preferences';
import { useMidnightReload } from '@/components/hub/use-midnight-reload';
import { Button } from '@/components/ui/button';
import { useNow } from '@/hooks/use-now';
import { useT } from '@/lib/i18n';

/**
 * The hub: "/" once the visitor has chosen a mosque. Its times are the
 * centre — a live countdown, today's times in the visitor's chosen style,
 * the adhan in the page — with the tracker, adhkar, campaigns and the
 * mosque's news around them. A mosque that publishes no calendar gets
 * calculated times, said plainly, with the nearest mosques that publish.
 */
export default function Hub({
    mosque,
    chosenBy,
    live,
    nearbyWithTimes,
    posts,
    tracker,
    preferences,
    defaults,
    canManage,
}: HubPageProps) {
    const t = useT();
    const now = useNow();
    const { prefs, update, reset } = useHubPreferences(preferences, defaults);
    const [sheetOpen, setSheetOpen] = useState(false);
    const catalog = useAdhanCatalog(mosque.slug);
    const track =
        catalog.tracks.find((item) => item.id === prefs.adhan_id) ??
        catalog.tracks[0] ??
        null;

    // A page left open past the mosque's midnight moves on to the next
    // published day, once an Isha published after midnight has been called.
    const date = dateInZone(live.timezone, now);
    // Without today's published times there is no day to show (never tomorrow's instead).
    const day = prayerDay(
        live.today ? [live.yesterday, live.today, live.tomorrow] : [],
        live.timezone,
        now,
    );
    const view = day
        ? buildDayView(day.today, day.tomorrow, live.timezone, now, day.offset)
        : null;
    // The server's date at the mosque when nothing is published today: a
    // page left open still picks up the next published day after midnight.
    useMidnightReload(date, live.today?.date ?? live.now.slice(0, 10));

    const adhan = useAdhan({ view, prefs, track, now });
    const calculated = isCalculated(live.today);

    // The adhan comes first: an open Customise sheet (a modal that blocks
    // clicks and focus outside it) closes so the overlay can be used.
    const momentKey = adhan.moment?.key ?? null;
    const [seenMoment, setSeenMoment] = useState<string | null>(null);

    if (momentKey !== seenMoment) {
        setSeenMoment(momentKey);

        if (momentKey !== null) {
            setSheetOpen(false);
        }
    }

    const StyleIcon = STYLE_ICON[prefs.style];

    return (
        <>
            <Head title={mosque.name} />

            <div className="mx-auto max-w-6xl space-y-5 sm:space-y-7">
                <HubHero
                    mosque={mosque}
                    view={view}
                    prefs={prefs}
                    now={now}
                    calculated={calculated}
                    corner={
                        view && (
                            <AdhanPill
                                prefs={prefs}
                                hasSound={track !== null}
                                onToggleMute={() =>
                                    update({ muted: !prefs.muted })
                                }
                                onOpenSettings={() => setSheetOpen(true)}
                            />
                        )
                    }
                />

                {view && adhan.needsUnlock && (
                    <SoundPrompt
                        onEnable={adhan.unlock}
                        onMute={() => update({ muted: true })}
                    />
                )}

                <QuickActions
                    mosque={mosque}
                    onCustomise={() => setSheetOpen(true)}
                />

                {canManage && (
                    <p className="flex flex-wrap items-center gap-x-2 gap-y-1 rounded-xl border border-dashed px-4 py-2.5 text-sm text-muted-foreground">
                        <ShieldCheck className="size-4 text-gold" aria-hidden />
                        {t('hub.manage_note')}
                        <Link
                            href={`/manage/${encodeURIComponent(mosque.slug)}`}
                            className="font-medium text-primary hover:underline"
                        >
                            {t('hub.manage_open')}
                        </Link>
                    </p>
                )}

                {view ? (
                    <section aria-labelledby="hub-today">
                        <header className="mb-3 flex items-center justify-between gap-3">
                            <h2
                                id="hub-today"
                                className="text-lg font-semibold"
                            >
                                {t('hub.today_title')}
                            </h2>
                            <Button
                                variant="ghost"
                                size="sm"
                                onClick={() => setSheetOpen(true)}
                                className="text-muted-foreground"
                            >
                                <StyleIcon />
                                {t(`hub.style_${prefs.style}`)}
                                <SlidersHorizontal className="ms-1" />
                            </Button>
                        </header>
                        <TimesDisplay
                            view={view}
                            prefs={prefs}
                            southern={mosque.lat < 0}
                            now={now}
                        />
                        {calculated && (
                            <CalculatedNotice
                                name={mosque.name}
                                method={live.today?.method}
                                className="mt-4"
                            >
                                <NearbyPublishing nearby={nearbyWithTimes} />
                            </CalculatedNotice>
                        )}
                    </section>
                ) : (
                    <NoTimes
                        mosqueName={mosque.name}
                        publishes={mosque.has_times}
                        nearby={nearbyWithTimes}
                    />
                )}

                <div className="grid gap-4 md:grid-cols-2">
                    {tracker ? (
                        <TrackerCheckIn
                            tracker={tracker}
                            view={view}
                            mosqueId={mosque.id}
                        />
                    ) : (
                        <AccountCard guest={chosenBy === 'cookie'} />
                    )}
                    <AdhkarSuggestion view={view} />
                </div>

                <MosqueCampaigns mosqueSlug={mosque.slug} />

                <LatestPosts posts={posts} mosqueSlug={mosque.slug} />
            </div>

            <CustomiseSheet
                open={sheetOpen}
                onOpenChange={setSheetOpen}
                prefs={prefs}
                signedIn={preferences !== null}
                tracks={catalog.tracks}
                tracksLoaded={catalog.loaded}
                playing={adhan.playing}
                onChange={update}
                onReset={reset}
                onPreview={adhan.preview}
                onStop={adhan.stop}
            />

            {adhan.moment && (
                <AdhanOverlay
                    moment={adhan.moment}
                    mosqueName={mosque.name}
                    prefs={prefs}
                    playing={adhan.playing}
                    blocked={adhan.blocked}
                    onPlay={adhan.playNow}
                    onStop={adhan.stop}
                    onClose={adhan.dismiss}
                />
            )}
        </>
    );
}
