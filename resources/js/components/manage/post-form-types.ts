import type { PostType } from '@/components/mosque/types';
import type { PublishStatus } from './status-badge';

export type CategoryOption = { id: number; name: string; slug: string };

/** PostController@edit — a post as the form edits it. */
export type EditablePost = {
    id: number;
    type: PostType;
    category_id: number | null;
    title: string;
    slug: string;
    excerpt: string;
    body: string;
    image_url: string | null;
    video_url: string;
    attachment: { name: string; url: string; size: number | null } | null;
    event_starts_at: string;
    pinned: boolean;
    status: PublishStatus;
    publish_at: string;
    published: boolean;
    url: string;
};

export type PostFormData = {
    type: PostType;
    category_id: string;
    title: string;
    slug: string;
    excerpt: string;
    body: string;
    video_url: string;
    event_starts_at: string;
    pinned: boolean;
    status: PublishStatus;
    publish_at: string;
    image: File | null;
    remove_image: boolean;
    attachment: File | null;
    remove_attachment: boolean;
};
