import { MosqueCampaigns } from '@/components/fundraising/mosque-campaigns';
import { ContactCard } from '@/components/mosque/contact-card';
import { DisplayCard } from '@/components/mosque/display-card';
import { HomeBlog } from '@/components/mosque/home-blog';
import { HomeEvents } from '@/components/mosque/home-events';
import { MosqueAbout } from '@/components/mosque/mosque-about';
import { MosqueHero } from '@/components/mosque/mosque-hero';
import { MosqueMap } from '@/components/mosque/mosque-map';
import { PageAccessCard } from '@/components/mosque/page-access-card';
import { PinnedBanner } from '@/components/mosque/pinned-banner';
import { PrayerSection } from '@/components/mosque/prayer-section';
import { SiteHead } from '@/components/mosque/site-head';
import { MosqueSiteShell } from '@/components/mosque/site-shell';
import type { MosqueHomeProps } from '@/components/mosque/site-types';
import { useLegacyPostAnchor } from '@/components/mosque/use-legacy-anchor';

/**
 * A mosque's home: its published prayer times at the centre, then its
 * announcements, events, campaigns, news and how to reach it.
 */
export default function MosqueShow({
    site,
    mosque,
    live,
    nearbyWithTimes,
    viewer,
    pinned,
    latest,
    events,
    aboutPage,
    shareUrl,
    meta,
}: MosqueHomeProps) {
    useLegacyPostAnchor(mosque.slug);

    return (
        <>
            <SiteHead meta={meta} />

            <MosqueSiteShell
                site={site}
                current="home"
                band={
                    <MosqueHero
                        site={site}
                        mosque={mosque}
                        viewer={viewer}
                        shareUrl={shareUrl}
                    />
                }
            >
                <div className="space-y-8 lg:space-y-10">
                    <PinnedBanner posts={pinned} />

                    <div className="grid gap-6 lg:grid-cols-3 lg:items-start lg:gap-8">
                        <div className="min-w-0 lg:col-span-2">
                            <PrayerSection
                                mosque={mosque}
                                live={live}
                                nearbyWithTimes={nearbyWithTimes}
                            />
                        </div>

                        <aside className="min-w-0 space-y-4">
                            {mosque.has_times && (
                                <DisplayCard
                                    slug={mosque.slug}
                                    canManage={viewer.can_manage}
                                />
                            )}
                            <HomeEvents
                                events={events}
                                timezone={mosque.timezone}
                            />
                            <MosqueMap mosque={mosque} />
                            <PageAccessCard mosque={mosque} viewer={viewer} />
                        </aside>
                    </div>

                    <MosqueCampaigns mosqueSlug={mosque.slug} />

                    <HomeBlog
                        site={site}
                        groups={latest}
                        canManage={viewer.can_manage}
                    />

                    <div className="grid gap-4 lg:grid-cols-3 lg:gap-8">
                        <div className="lg:col-span-2">
                            <MosqueAbout
                                mosque={mosque}
                                aboutPage={aboutPage}
                            />
                        </div>
                        <ContactCard mosque={mosque} />
                    </div>
                </div>
            </MosqueSiteShell>
        </>
    );
}
