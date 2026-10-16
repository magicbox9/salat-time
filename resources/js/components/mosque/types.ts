import type { LiveTimes, MosqueSummary } from '@/types/mosque';

/** MosqueProfile::details — the public profile shown on a mosque page. */
export type MosqueDetails = MosqueSummary & {
    association: string | null;
    description: string | null;
    website: string | null;
    phone: string | null;
    email: string | null;
    cover_url: string | null;
    jumua: string[];
    jumua_as_dhuhr: boolean;
};

/** What the current visitor may do on the page (MosqueProfile::viewer). */
export type MosqueViewer = {
    signed_in: boolean;
    verified: boolean;
    favorite: boolean;
    primary: boolean;
    can_manage: boolean;
    pending_claim: boolean;
};

export const POST_TYPES = ['news', 'event', 'announcement', 'janaza'] as const;

export type PostType = (typeof POST_TYPES)[number];

/** PostPresenter::post */
export type MosquePost = {
    id: number;
    type: PostType;
    title: string;
    body: string;
    image_url: string | null;
    event_starts_at: string | null;
    pinned: boolean;
    published_at: string | null;
    comments_count: number;
};

/** PostPresenter::comment */
export type PostComment = {
    id: number;
    body: string;
    author: string;
    created_at: string | null;
    hidden: boolean;
    mine: boolean;
    can_delete: boolean;
    can_moderate: boolean;
};

/** A cursor page: GET /mosques/{slug}/posts.json and …/comments. */
export type CursorPage<T> = {
    data: T[];
    next_cursor: string | null;
};

/** Props of the 'mosques/show' page. */
export type MosquePageProps = {
    mosque: MosqueDetails;
    live: Omit<LiveTimes, 'days'>;
    nearbyWithTimes: MosqueSummary[];
    viewer: MosqueViewer;
    pinned: MosquePost[];
    feed: CursorPage<MosquePost>;
    shareUrl: string;
};
