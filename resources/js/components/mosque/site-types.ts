import type { LiveTimes, MosqueSummary } from '@/types/mosque';
import type { MosqueDetails, MosqueViewer, PostType } from './types';

/**
 * AccentColor::present — the mosque's colour, the text colour that reads on
 * it, and the colour itself made dark enough to read as text on white.
 */
export type SiteAccent = {
    color: string;
    foreground: string;
    ink: string;
} | null;

export const SOCIAL_NETWORKS = [
    'facebook',
    'instagram',
    'youtube',
    'x',
    'tiktok',
    'whatsapp',
    'telegram',
] as const;

export type SocialNetwork = (typeof SOCIAL_NETWORKS)[number];

/** SocialLinks::present */
export type SocialLink = { network: SocialNetwork; url: string };

/** MosqueSite::shell — the frame shared by every page of a mosque's site. */
export type SiteShell = {
    slug: string;
    name: string;
    tagline: string | null;
    city: string | null;
    timezone: string;
    verified: boolean;
    logo_url: string | null;
    cover_url: string | null;
    accent: SiteAccent;
    menu: { title: string; slug: string }[];
    contact_page: string | null;
    khutbah: boolean;
    donate: boolean;
};

/** MosqueSite::meta — for search engines and link previews. */
export type SiteMeta = {
    title: string;
    description: string;
    image: string | null;
    url: string;
    type: string;
};

export type PostCategoryRef = { id: number; name: string; slug: string };

/** PostPresenter::card */
export type PostCardData = {
    id: number;
    slug: string | null;
    url: string;
    type: PostType;
    title: string;
    excerpt: string;
    image_url: string | null;
    category: PostCategoryRef | null;
    published_at: string | null;
    event_starts_at: string | null;
    pinned: boolean;
    has_video: boolean;
    has_attachment: boolean;
    comments_count: number;
};

export type VideoEmbedData = {
    provider: 'youtube' | 'vimeo';
    id: string;
    url: string;
    embed_url: string;
};

export type AttachmentData = { name: string; url: string; size: number | null };

/** ArticlePresenter::article */
export type ArticleData = PostCardData & {
    body_html: string;
    author: string | null;
    updated_at: string | null;
    status: 'published' | 'scheduled' | 'draft';
    video: VideoEmbedData | null;
    attachment: AttachmentData | null;
};

export type Neighbour = {
    title: string;
    url: string;
    published_at: string | null;
} | null;

export type LatestGroup = {
    category: PostCategoryRef | null;
    posts: PostCardData[];
};

export type SiteMosqueDetails = MosqueDetails & {
    tagline: string | null;
    accent: SiteAccent;
    social_links: SocialLink[];
};

/** Props of the 'mosques/show' page (the mosque's home). */
export type MosqueHomeProps = {
    site: SiteShell;
    mosque: SiteMosqueDetails;
    live: Omit<LiveTimes, 'days'>;
    nearbyWithTimes: MosqueSummary[];
    viewer: MosqueViewer;
    pinned: PostCardData[];
    latest: LatestGroup[];
    events: PostCardData[];
    aboutPage: { title: string; slug: string } | null;
    shareUrl: string;
    meta: SiteMeta;
};
