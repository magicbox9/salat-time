import { usePage } from '@inertiajs/react';
import { LocateFixed, Search } from 'lucide-react';
import type { FormEvent, KeyboardEvent } from 'react';
import { useId, useState } from 'react';
import { Button } from '@/components/ui/button';
import { Spinner } from '@/components/ui/spinner';
import { useT } from '@/lib/i18n';
import { cn } from '@/lib/utils';
import type { MosqueSummary } from '@/types/mosque';
import { countryName } from './countries';
import { CountrySelect } from './country-select';
import type { Suggestion } from './search-suggestions';
import { optionId, SearchSuggestions } from './search-suggestions';
import type { Place } from './types';
import {
    MIN_MOSQUE_QUERY,
    MIN_PLACE_QUERY,
    usePlaceSearch,
} from './use-place-search';

type Props = {
    /** "hero": the glassy card on the globe; "docked": the compact bar once results show. */
    variant: 'hero' | 'docked';
    country: string;
    onCountryChange: (code: string) => void;
    onPlace: (place: Place) => void;
    onMosque: (mosque: MosqueSummary) => void;
    onLocate: () => void;
    locating: boolean;
    className?: string;
};

/** Country, "city, postcode or address" with suggestions, and "use my location". */
export function SearchCard({
    variant,
    country,
    onCountryChange,
    onPlace,
    onMosque,
    onLocate,
    locating,
    className,
}: Props) {
    const t = useT();
    const { locale } = usePage().props;
    const listId = useId();
    const [query, setQuery] = useState('');
    const [open, setOpen] = useState(false);
    const [active, setActive] = useState(-1);
    const search = usePlaceSearch(
        query,
        country,
        t('discover.geocode_unavailable'),
    );
    const hero = variant === 'hero';
    const term = query.trim();

    const suggestions: Suggestion[] = [
        ...search.places.map((place) => ({ type: 'place' as const, place })),
        ...search.mosques.map((mosque) => ({
            type: 'mosque' as const,
            mosque,
        })),
    ];
    const awaitingEnter =
        !search.live &&
        term.length >= MIN_PLACE_QUERY &&
        !search.placesAnswered &&
        !search.loadingPlaces;
    const showList =
        open &&
        term.length >= MIN_MOSQUE_QUERY &&
        (suggestions.length > 0 ||
            search.loadingPlaces ||
            search.placesAnswered ||
            awaitingEnter);
    // The listbox itself exists only when there is something to choose.
    const listShown = showList && suggestions.length > 0;

    const pick = (suggestion: Suggestion) => {
        setOpen(false);
        setActive(-1);

        if (suggestion.type === 'place') {
            setQuery(suggestion.place.label);
            onPlace(suggestion.place);
        } else {
            setQuery(suggestion.mosque.name);
            onMosque(suggestion.mosque);
        }
    };

    const submit = async (event: FormEvent) => {
        event.preventDefault();

        if (active >= 0 && suggestions[active]) {
            pick(suggestions[active]);

            return;
        }

        if (search.places.length > 0) {
            pick({ type: 'place', place: search.places[0] });

            return;
        }

        const places = await search.lookUpPlaces();
        setOpen(true);

        if (places.length === 1 || (search.live && places.length > 0)) {
            pick({ type: 'place', place: places[0] });
        }
    };

    const onKeyDown = (event: KeyboardEvent<HTMLInputElement>) => {
        if (event.key === 'ArrowDown' || event.key === 'ArrowUp') {
            event.preventDefault();
            setOpen(true);
            const step = event.key === 'ArrowDown' ? 1 : -1;
            setActive((index) =>
                suggestions.length
                    ? (index + step + suggestions.length) % suggestions.length
                    : -1,
            );
        } else if (event.key === 'Escape') {
            setOpen(false);
            setActive(-1);
        }
    };

    return (
        <div
            className={cn(
                hero
                    ? 'w-full max-w-xl rounded-3xl border border-white/15 bg-[oklch(0.2_0.03_200/0.55)] p-5 text-white shadow-2xl ring-1 ring-black/5 backdrop-blur-xl sm:p-7'
                    : 'w-full rounded-2xl border bg-background/92 p-2.5 text-foreground shadow-xl backdrop-blur-xl',
                className,
            )}
        >
            {hero && (
                <div className="mb-5">
                    <p className="text-xs font-semibold tracking-[0.25em] text-gold uppercase">
                        {t('discover.eyebrow')}
                    </p>
                    <h1 className="mt-2 text-2xl font-semibold tracking-tight text-balance sm:text-3xl">
                        {t('discover.title')}
                    </h1>
                    <p className="mt-1.5 text-sm text-white/75 sm:text-base">
                        {t('discover.subtitle')}
                    </p>
                </div>
            )}

            <form
                role="search"
                onSubmit={submit}
                className={cn(
                    'flex gap-2',
                    hero ? 'flex-col sm:flex-row' : 'flex-row',
                )}
                onBlur={(event) => {
                    if (
                        !event.currentTarget.contains(
                            event.relatedTarget as Node | null,
                        )
                    ) {
                        setOpen(false);
                    }
                }}
            >
                <CountrySelect
                    value={country}
                    onChange={onCountryChange}
                    glass={hero}
                    compact={!hero}
                />
                <div className="relative min-w-0 flex-1">
                    <Search
                        className={cn(
                            'pointer-events-none absolute start-3 top-1/2 size-4 -translate-y-1/2',
                            hero ? 'text-white/60' : 'text-muted-foreground',
                        )}
                        aria-hidden
                    />
                    <input
                        type="search"
                        value={query}
                        maxLength={200}
                        autoComplete="off"
                        enterKeyHint="search"
                        role="combobox"
                        aria-expanded={listShown}
                        aria-controls={listShown ? listId : undefined}
                        aria-autocomplete="list"
                        aria-activedescendant={
                            listShown && active >= 0 && suggestions[active]
                                ? optionId(listId, active)
                                : undefined
                        }
                        aria-label={t('discover.query_label')}
                        placeholder={t('discover.query_placeholder')}
                        onChange={(event) => {
                            setQuery(event.target.value);
                            setOpen(true);
                            setActive(-1);
                        }}
                        onFocus={() => setOpen(true)}
                        onKeyDown={onKeyDown}
                        className={cn(
                            'h-11 w-full rounded-xl border ps-9 pe-3 text-base transition-[box-shadow,border-color] outline-none focus-visible:ring-[3px] md:text-sm',
                            hero
                                ? 'border-white/20 bg-white/10 text-white placeholder:text-white/55 focus-visible:border-gold/70 focus-visible:ring-gold/30'
                                : 'border-input bg-background placeholder:text-muted-foreground focus-visible:border-ring focus-visible:ring-ring/40',
                        )}
                    />
                    {showList && (
                        <SearchSuggestions
                            id={listId}
                            suggestions={suggestions}
                            active={active}
                            loadingPlaces={search.loadingPlaces}
                            placesError={search.placesError}
                            placesAnswered={search.placesAnswered}
                            awaitingEnter={awaitingEnter}
                            countryName={countryName(country, locale)}
                            above={hero}
                            onPick={pick}
                            onActive={setActive}
                        />
                    )}
                </div>
                {!hero && (
                    <Button
                        type="button"
                        variant="outline"
                        size="icon"
                        className="size-11 shrink-0 rounded-xl"
                        onClick={onLocate}
                        disabled={locating}
                        aria-label={t('discover.use_location')}
                    >
                        {locating ? <Spinner /> : <LocateFixed />}
                    </Button>
                )}
            </form>

            {hero && (
                <div className="mt-4 flex flex-wrap items-center justify-between gap-3">
                    <Button
                        type="button"
                        variant="ghost"
                        onClick={onLocate}
                        disabled={locating}
                        className="-ms-3 text-white hover:bg-white/10 hover:text-white"
                    >
                        {locating ? (
                            <Spinner />
                        ) : (
                            <LocateFixed className="text-gold" />
                        )}
                        {t('discover.use_location')}
                    </Button>
                    <p className="text-xs text-white/60">
                        {t('discover.hint')}
                    </p>
                </div>
            )}
        </div>
    );
}
