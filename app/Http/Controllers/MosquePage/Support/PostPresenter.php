<?php

namespace App\Http\Controllers\MosquePage\Support;

use App\Models\Mosque;
use App\Models\MosquePost;
use App\Models\MosquePostCategory;
use App\Models\PostComment;
use App\Models\User;
use App\Support\Markdown;
use Carbon\CarbonInterface;

/** JSON shapes for posts and comments (TS types in components/mosque/types.ts). */
class PostPresenter
{
    /** @return array<string, mixed> */
    public static function post(MosquePost $post, ?string $mosqueSlug = null): array
    {
        return [
            'id' => $post->id,
            'type' => $post->type,
            'title' => $post->title,
            'slug' => $post->slug,
            'url' => $mosqueSlug !== null ? self::articleUrl($mosqueSlug, $post) : null,
            'body' => $post->body,
            'image_url' => self::url($post->image_path),
            'event_starts_at' => self::iso($post->event_starts_at),
            'pinned' => (bool) $post->pinned,
            'published_at' => self::iso($post->published_at),
            'comments_count' => (int) ($post->comments_count ?? 0),
        ];
    }

    /**
     * A post as a card of the blog (no body: an excerpt instead).
     *
     * @return array<string, mixed>
     */
    public static function card(MosquePost $post, Mosque $mosque): array
    {
        return [
            'id' => $post->id,
            'slug' => $post->slug,
            'url' => self::articleUrl($mosque->slug, $post),
            'type' => $post->type,
            'title' => $post->title,
            'excerpt' => self::excerpt($post),
            'image_url' => self::url($post->image_path),
            'category' => self::category($post),
            'published_at' => self::iso($post->published_at),
            'event_starts_at' => self::iso($post->event_starts_at),
            'pinned' => (bool) $post->pinned,
            'has_video' => VideoEmbed::parse($post->video_url) !== null,
            'has_attachment' => $post->attachment_path !== null,
            'comments_count' => (int) ($post->comments_count ?? 0),
        ];
    }

    /** @return array{id: int, name: string, slug: string}|null */
    public static function category(MosquePost $post): ?array
    {
        $category = $post->relationLoaded('category') ? $post->getRelation('category') : null;

        return $category instanceof MosquePostCategory
            ? ['id' => $category->id, 'name' => $category->name, 'slug' => $category->slug]
            : null;
    }

    public static function excerpt(MosquePost $post, int $length = 180): string
    {
        return $post->excerpt ?: Markdown::excerpt($post->body, $length);
    }

    public static function articleUrl(string $mosqueSlug, MosquePost $post): string
    {
        return $post->slug
            ? '/mosques/'.$mosqueSlug.'/blog/'.$post->slug
            : '/mosques/'.$mosqueSlug.'/posts/'.$post->id;
    }

    /** @return array<string, mixed> */
    public static function comment(PostComment $comment, ?User $viewer, bool $moderator): array
    {
        $author = $comment->user;

        return [
            'id' => $comment->id,
            'body' => $comment->body,
            'author' => $author instanceof User ? $author->name : '',
            'created_at' => self::iso($comment->created_at),
            'hidden' => $comment->hidden_at !== null,
            'mine' => $viewer !== null && $viewer->id === $comment->user_id,
            'can_delete' => $viewer !== null && ($viewer->id === $comment->user_id || $viewer->is_admin),
            'can_moderate' => $moderator,
        ];
    }

    public static function iso(mixed $date): ?string
    {
        return $date instanceof CarbonInterface ? $date->toIso8601String() : null;
    }

    public static function url(?string $path): ?string
    {
        return $path ? asset('storage/'.$path) : null;
    }
}
