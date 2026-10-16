import type { DayTimes, MosqueSummary } from '@/types/mosque';

/** Only the published times of a day (enough for the next-prayer countdown). */
export type DayTimesLite = Pick<DayTimes, 'date' | 'times'>;

/** A mosque card on the map and in lists (GET /mosques/near.json, /me/mosques). */
export type MosqueCard = MosqueSummary & {
    is_favorite: boolean;
    is_primary: boolean;
    today: DayTimesLite | null;
    tomorrow: DayTimesLite | null;
};

/** The smallest mosque record the map can show and select (a dot, a card, a favourite). */
export type MosquePin = {
    id: number;
    slug: string;
    name: string;
    city: string | null;
    lat: number;
    lng: number;
    has_times: boolean;
    address?: string | null;
    postcode?: string | null;
    distance_m?: number | null;
    verified?: boolean;
    google_maps_url?: string;
    is_primary?: boolean;
};

/** GET /mosques/near.json */
export type NearbyResponse = {
    origin: { lat: number; lng: number };
    radius_km: number;
    mosques: MosqueCard[];
};

/** GET /mosques/in-bounds.json */
export type BoundsResponse = {
    truncated: boolean;
    mosques: MosquePin[];
};

export type PlaceKind =
    | 'address'
    | 'street'
    | 'city'
    | 'postcode'
    | 'region'
    | 'place';

/** GET /geocode.json */
export type Place = {
    label: string;
    lat: number;
    lng: number;
    city: string | null;
    postcode: string | null;
    country: string;
    kind: PlaceKind;
};

/** Answer of the favourite / "my mosque" endpoints. */
export type FavoriteState = {
    slug: string;
    is_favorite: boolean;
    is_primary: boolean;
    message: string;
};

/** Where the visitor searched from (a place, their position, a mosque). */
export type Origin = {
    lat: number;
    lng: number;
    label: string;
    kind: PlaceKind | 'mosque' | 'me';
};
