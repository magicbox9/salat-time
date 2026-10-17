import { Head, Link, router } from '@inertiajs/react';
import { HandCoins, LocateFixed, MapPin, ShieldCheck, X } from 'lucide-react';
import { useState } from 'react';
import { KIND_ICONS } from '@/components/fundraising/badges';
import { CampaignCard } from '@/components/fundraising/campaign-card';
import type {
    CampaignCardData,
    CampaignKind,
} from '@/components/fundraising/types';
import { Pager } from '@/components/manage/pager';
import type { Paginated } from '@/components/manage/pager';
import { Arabesque } from '@/components/mosque/arabesque';
import { Button } from '@/components/ui/button';
import { Spinner } from '@/components/ui/spinner';
import { useT } from '@/lib/i18n';
import { cn } from '@/lib/utils';

type Filters = {
    kind: CampaignKind | null;
    tab: 'open' | 'ended';
    near: 'mine' | 'here' | null;
};

type Props = {
    campaigns: Paginated<CampaignCardData> & { total: number };
    filters: Filters;
    kinds: CampaignKind[];
    chosenMosque: { slug: string; name: string } | null;
};

/** /campaigns — give to mosques: open campaigns, by kind, near you. */
export default function CampaignsIndex({
    campaigns,
    filters,
    kinds,
    chosenMosque,
}: Props) {
    const t = useT();
    const [locating, setLocating] = useState(false);
    const [geoError, setGeoError] = useState(false);

    const visit = (next: Partial<Filters> & { lat?: number; lng?: number }) => {
        const merged = { ...filters, ...next };
        const query: Record<string, string> = {};

        if (merged.kind) query.kind = merged.kind;
        if (merged.tab === 'ended') query.tab = 'ended';
        if (merged.near) query.near = merged.near;
        if (
            merged.near === 'here' &&
            next.lat !== undefined &&
            next.lng !== undefined
        ) {
            // About a kilometre: enough for "near me", kinder to privacy.
            query.lat = next.lat.toFixed(2);
            query.lng = next.lng.toFixed(2);
        } else if (merged.near === 'here') {
            const params = new URLSearchParams(window.location.search);
            query.lat = params.get('lat') ?? '';
            query.lng = params.get('lng') ?? '';
        }

        router.get('/campaigns', query, {
            preserveScroll: true,
            preserveState: true,
        });
    };

    const nearMe = () => {
        if (chosenMosque) {
            visit({ near: 'mine' });

            return;
        }

        if (!navigator.geolocation) {
            setGeoError(true);

            return;
        }

        setLocating(true);
        setGeoError(false);
        navigator.geolocation.getCurrentPosition(
            (position) => {
                setLocating(false);
                visit({
                    near: 'here',
                    lat: position.coords.latitude,
                    lng: position.coords.longitude,
                });
            },
            () => {
                setLocating(false);
                setGeoError(true);
            },
            { maximumAge: 600_000, timeout: 10_000 },
        );
    };

    return (
        <>
            <Head title={t('fundraising.explore_title')} />
            <div className="space-y-8">
                <section className="relative isolate overflow-hidden rounded-3xl bg-[oklch(0.34_0.07_170)] px-6 py-10 text-white shadow-sm sm:px-10 sm:py-14">
                    <div className="absolute inset-0 -z-10">
                        <Arabesque />
                    </div>
                    <div className="max-w-2xl space-y-4">
                        <p className="inline-flex items-center gap-2 rounded-full bg-white/10 px-3 py-1 text-sm font-medium text-white ring-1 ring-white/20 backdrop-blur">
                            <HandCoins
                                className="size-4 text-gold"
                                aria-hidden
                            />
                            {t('fundraising.explore_eyebrow')}
                        </p>
                        <h1 className="text-3xl font-semibold tracking-tight text-balance text-white sm:text-4xl">
                            {t('fundraising.explore_title')}
                        </h1>
                        <p className="text-lg text-pretty text-white/85">
                            {t('fundraising.explore_intro')}
                        </p>
                        <p className="flex items-start gap-2 text-sm text-white/80">
                            <ShieldCheck
                                className="mt-0.5 size-4 shrink-0 text-gold"
                                aria-hidden
                            />
                            {t('fundraising.explore_trust')}
                        </p>
                    </div>
                </section>

                <div className="flex flex-col gap-4 lg:flex-row lg:items-center lg:justify-between">
                    <div
                        className="flex gap-1 self-start rounded-xl bg-muted p-1"
                        role="tablist"
                        aria-label={t('fundraising.tabs_label')}
                    >
                        {(['open', 'ended'] as const).map((tab) => (
                            <button
                                key={tab}
                                type="button"
                                role="tab"
                                aria-selected={filters.tab === tab}
                                onClick={() => visit({ tab })}
                                className={cn(
                                    'rounded-lg px-4 py-1.5 text-sm font-medium transition-colors',
                                    filters.tab === tab
                                        ? 'bg-background shadow-sm'
                                        : 'text-muted-foreground hover:text-foreground',
                                )}
                            >
                                {t(`fundraising.tab_${tab}`)}
                            </button>
                        ))}
                    </div>

                    <div className="flex flex-wrap items-center gap-2">
                        {filters.near ? (
                            <Button
                                variant="secondary"
                                size="sm"
                                onClick={() => visit({ near: null })}
                                title={t('fundraising.clear_filter')}
                            >
                                <MapPin
                                    className="size-4 text-primary"
                                    aria-hidden
                                />
                                {filters.near === 'mine' && chosenMosque
                                    ? t('fundraising.near_mosque', {
                                          mosque: chosenMosque.name,
                                      })
                                    : t('fundraising.near_you')}
                                <X className="size-3.5" aria-hidden />
                            </Button>
                        ) : (
                            <Button
                                variant="outline"
                                size="sm"
                                onClick={nearMe}
                                disabled={locating}
                            >
                                {locating ? (
                                    <Spinner />
                                ) : (
                                    <LocateFixed
                                        className="size-4"
                                        aria-hidden
                                    />
                                )}
                                {t('fundraising.near_me')}
                            </Button>
                        )}
                    </div>
                </div>

                {geoError && (
                    <p className="text-sm text-muted-foreground">
                        {t('fundraising.geo_error')}
                    </p>
                )}

                <nav
                    aria-label={t('fundraising.kinds_label')}
                    className="-mx-4 overflow-x-auto px-4 pb-1"
                >
                    <ul className="flex w-max gap-2">
                        <li>
                            <KindChip
                                active={filters.kind === null}
                                onClick={() => visit({ kind: null })}
                                label={t('fundraising.kind_all')}
                            />
                        </li>
                        {kinds.map((kind) => {
                            const Icon = KIND_ICONS[kind];

                            return (
                                <li key={kind}>
                                    <KindChip
                                        active={filters.kind === kind}
                                        onClick={() => visit({ kind })}
                                        label={t(`fundraising.kind_${kind}`)}
                                        icon={
                                            <Icon
                                                className="size-4"
                                                aria-hidden
                                            />
                                        }
                                    />
                                </li>
                            );
                        })}
                    </ul>
                </nav>

                {campaigns.data.length === 0 ? (
                    <div className="rounded-3xl border border-dashed px-6 py-16 text-center">
                        <HandCoins
                            className="mx-auto size-10 text-gold"
                            aria-hidden
                        />
                        <p className="mt-4 text-lg font-medium">
                            {t(
                                filters.near
                                    ? 'fundraising.empty_near'
                                    : 'fundraising.empty_title',
                            )}
                        </p>
                        <p className="mx-auto mt-1 max-w-md text-sm text-muted-foreground">
                            {t('fundraising.empty_body')}
                        </p>
                        {(filters.near || filters.kind) && (
                            <Button asChild variant="outline" className="mt-5">
                                <Link href="/campaigns">
                                    {t('fundraising.see_every_campaign')}
                                </Link>
                            </Button>
                        )}
                    </div>
                ) : (
                    <ul className="grid gap-5 sm:grid-cols-2 xl:grid-cols-3 2xl:grid-cols-4">
                        {campaigns.data.map((campaign) => (
                            <li key={campaign.id} className="flex">
                                <CampaignCard
                                    campaign={campaign}
                                    className="w-full"
                                />
                            </li>
                        ))}
                    </ul>
                )}

                <Pager page={campaigns} />
            </div>
        </>
    );
}

function KindChip({
    active,
    onClick,
    label,
    icon,
}: {
    active: boolean;
    onClick: () => void;
    label: string;
    icon?: React.ReactNode;
}) {
    return (
        <button
            type="button"
            aria-pressed={active}
            onClick={onClick}
            className={cn(
                'inline-flex items-center gap-2 rounded-full border px-4 py-2 text-sm font-medium whitespace-nowrap transition-colors outline-none focus-visible:ring-[3px] focus-visible:ring-ring/50',
                active
                    ? 'border-primary bg-primary text-primary-foreground shadow-sm'
                    : 'bg-card text-muted-foreground hover:border-primary/40 hover:text-foreground',
            )}
        >
            {icon}
            {label}
        </button>
    );
}
