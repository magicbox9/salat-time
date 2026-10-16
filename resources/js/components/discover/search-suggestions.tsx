import { Building2, MapPin } from 'lucide-react';
import { Spinner } from '@/components/ui/spinner';
import { useT } from '@/lib/i18n';
import { cn } from '@/lib/utils';
import type { MosqueSummary } from '@/types/mosque';
import type { Place } from './types';

export type Suggestion =
    | { type: 'place'; place: Place }
    | { type: 'mosque'; mosque: MosqueSummary };

type Props = {
    id: string;
    suggestions: Suggestion[];
    active: number;
    loadingPlaces: boolean;
    placesError: string | null;
    /** A place search answered this exact text (with or without results). */
    placesAnswered: boolean;
    /** Text long enough for a place search that has not been sent yet (Enter needed). */
    awaitingEnter: boolean;
    countryName: string;
    /** Open upwards when the box sits low on the screen (the card under the globe). */
    above: boolean;
    onPick: (suggestion: Suggestion) => void;
    onActive: (index: number) => void;
};

export const optionId = (listId: string, index: number) =>
    `${listId}-option-${index}`;

/** The dropdown under the search box: places first, then mosques by name. */
export function SearchSuggestions({
    id,
    suggestions,
    active,
    loadingPlaces,
    placesError,
    placesAnswered,
    awaitingEnter,
    countryName,
    above,
    onPick,
    onActive,
}: Props) {
    const t = useT();
    const firstMosque = suggestions.findIndex((s) => s.type === 'mosque');
    const hasPlaces = suggestions.some((s) => s.type === 'place');
    const status = loadingPlaces
        ? t('discover.searching')
        : placesError
          ? placesError
          : awaitingEnter
            ? t('discover.press_enter', { country: countryName })
            : placesAnswered && !hasPlaces
              ? t('discover.no_place')
              : null;

    return (
        <div
            className={cn(
                'absolute inset-x-0 z-50 overflow-hidden rounded-xl border bg-popover text-popover-foreground shadow-2xl',
                above ? 'bottom-full mb-2' : 'top-full mt-2',
            )}
        >
            {status && (
                <p
                    role="status"
                    className={cn(
                        'flex items-center gap-2 px-3 py-2.5 text-sm',
                        placesError
                            ? 'text-destructive'
                            : 'text-muted-foreground',
                    )}
                >
                    {loadingPlaces && <Spinner className="size-3.5" />}
                    {status}
                </p>
            )}
            {suggestions.length > 0 && (
                <ul
                    id={id}
                    role="listbox"
                    aria-label={t('discover.suggestions')}
                    className="max-h-[min(20rem,45svh)] overflow-y-auto py-1"
                >
                    {suggestions.map((suggestion, index) => {
                        const heading =
                            index === 0 && suggestion.type === 'place'
                                ? t('discover.places')
                                : index === firstMosque
                                  ? t('discover.mosques')
                                  : null;
                        const Icon =
                            suggestion.type === 'place' ? MapPin : Building2;
                        const title =
                            suggestion.type === 'place'
                                ? suggestion.place.label
                                : suggestion.mosque.name;
                        const detail =
                            suggestion.type === 'place'
                                ? t(`discover.kind_${suggestion.place.kind}`)
                                : [
                                      suggestion.mosque.postcode,
                                      suggestion.mosque.city,
                                  ]
                                      .filter(Boolean)
                                      .join(' ');

                        return (
                            <li
                                key={`${suggestion.type}-${index}`}
                                role="presentation"
                            >
                                {heading && (
                                    <p
                                        role="presentation"
                                        className="px-3 pt-2 pb-1 text-[11px] font-semibold tracking-wider text-muted-foreground uppercase"
                                    >
                                        {heading}
                                    </p>
                                )}
                                <div
                                    id={optionId(id, index)}
                                    role="option"
                                    aria-selected={index === active}
                                    onMouseDown={(event) =>
                                        event.preventDefault()
                                    }
                                    onMouseEnter={() => onActive(index)}
                                    onClick={() => onPick(suggestion)}
                                    className={cn(
                                        'flex cursor-pointer items-center gap-3 px-3 py-2 text-sm',
                                        index === active &&
                                            'bg-accent text-accent-foreground',
                                    )}
                                >
                                    <Icon
                                        className={cn(
                                            'size-4 shrink-0',
                                            suggestion.type === 'mosque'
                                                ? 'text-primary'
                                                : 'text-muted-foreground',
                                        )}
                                        aria-hidden
                                    />
                                    <span className="min-w-0 flex-1">
                                        <span className="block truncate">
                                            {title}
                                        </span>
                                        {detail && (
                                            <span className="block truncate text-xs text-muted-foreground">
                                                {detail}
                                            </span>
                                        )}
                                    </span>
                                </div>
                            </li>
                        );
                    })}
                </ul>
            )}
        </div>
    );
}
