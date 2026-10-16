import { Head } from '@inertiajs/react';
import { MosqueAbout } from '@/components/mosque/mosque-about';
import { MosqueHero } from '@/components/mosque/mosque-hero';
import { MosqueMap } from '@/components/mosque/mosque-map';
import {
    DonationsCard,
    PageAccessCard,
} from '@/components/mosque/page-access-card';
import { PostFeed } from '@/components/mosque/post-feed';
import { PrayerSection } from '@/components/mosque/prayer-section';
import type { MosquePageProps } from '@/components/mosque/types';
import { useT } from '@/lib/i18n';

/** A mosque's public page: its published times, its news, and how to reach it. */
export default function MosqueShow({
    mosque,
    live,
    nearbyWithTimes,
    viewer,
    pinned,
    feed,
    shareUrl,
}: MosquePageProps) {
    const t = useT();
    const place = [mosque.city, mosque.postcode].filter(Boolean).join(' ');

    return (
        <>
            <Head title={mosque.name}>
                <meta
                    head-key="description"
                    name="description"
                    content={t('mosque.meta_description', {
                        name: mosque.name,
                        place,
                    })}
                />
                <meta
                    head-key="og:title"
                    property="og:title"
                    content={mosque.name}
                />
                <meta head-key="og:url" property="og:url" content={shareUrl} />
                {mosque.cover_url && (
                    <meta
                        head-key="og:image"
                        property="og:image"
                        content={mosque.cover_url}
                    />
                )}
            </Head>

            <div className="space-y-8">
                <MosqueHero
                    mosque={mosque}
                    viewer={viewer}
                    shareUrl={shareUrl}
                />

                <div className="grid gap-6 lg:grid-cols-3 lg:grid-rows-[auto_1fr] lg:items-start lg:gap-8">
                    <div className="min-w-0 lg:col-span-2">
                        <PrayerSection
                            mosque={mosque}
                            live={live}
                            nearbyWithTimes={nearbyWithTimes}
                        />
                    </div>

                    <aside className="min-w-0 space-y-4 lg:col-start-3 lg:row-span-2 lg:row-start-1">
                        <MosqueMap mosque={mosque} />
                        <MosqueAbout mosque={mosque} />
                        <PageAccessCard mosque={mosque} viewer={viewer} />
                        {mosque.verified && <DonationsCard />}
                    </aside>

                    <div className="min-w-0 lg:col-span-2">
                        <PostFeed
                            slug={mosque.slug}
                            timezone={mosque.timezone}
                            pinned={pinned}
                            feed={feed}
                            viewer={viewer}
                        />
                    </div>
                </div>
            </div>
        </>
    );
}
