<?php

namespace App\Http\Controllers\MosquePage\Support;

use App\Models\Mosque;
use App\Models\MosquePost;
use App\Models\User;
use App\Support\Markdown;
use Illuminate\Support\Facades\Storage;
use Throwable;

/** A blog post as its own page: Markdown body, khutbah video, PDF, neighbours. */
final class ArticlePresenter
{
    /** @return array<string, mixed> */
    public static function article(MosquePost $post, Mosque $mosque): array
    {
        $author = $post->relationLoaded('author') ? $post->getRelation('author') : null;

        return [
            ...PostPresenter::card($post, $mosque),
            'body_html' => Markdown::toHtml($post->body),
            'author' => $author instanceof User ? $author->name : null,
            'updated_at' => PostPresenter::iso($post->updated_at),
            'status' => BlogPosts::status($post),
            'video' => VideoEmbed::parse($post->video_url),
            'attachment' => self::attachment($post),
        ];
    }

    /** @return array{name: string, url: string, size: int|null}|null */
    public static function attachment(MosquePost $post): ?array
    {
        if (! $post->attachment_path) {
            return null;
        }

        try {
            $size = Storage::disk('public')->size($post->attachment_path);
        } catch (Throwable) {
            $size = null;
        }

        return [
            'name' => $post->attachment_name ?: basename($post->attachment_path),
            'url' => (string) PostPresenter::url($post->attachment_path),
            'size' => $size,
        ];
    }

    /**
     * The published posts just before and after this one.
     *
     * @return array{previous: array<string, mixed>|null, next: array<string, mixed>|null}
     */
    public static function neighbours(MosquePost $post, Mosque $mosque): array
    {
        if (! BlogPosts::isPublic($post)) {
            return ['previous' => null, 'next' => null];
        }

        $at = $post->published_at;
        $find = fn (string $direction) => BlogPosts::published($mosque)
            ->where(fn ($q) => $direction === 'older'
                ? $q->where('published_at', '<', $at)->orWhere(fn ($q) => $q->where('published_at', $at)->where('id', '<', $post->id))
                : $q->where('published_at', '>', $at)->orWhere(fn ($q) => $q->where('published_at', $at)->where('id', '>', $post->id)))
            ->orderBy('published_at', $direction === 'older' ? 'desc' : 'asc')
            ->orderBy('id', $direction === 'older' ? 'desc' : 'asc')
            ->first(['id', 'mosque_id', 'title', 'slug', 'published_at']);

        $present = function (?MosquePost $neighbour) use ($mosque): ?array {
            if (! $neighbour) {
                return null;
            }
            Slugs::ensureForPosts([$neighbour]);

            return [
                'title' => $neighbour->title,
                'url' => PostPresenter::articleUrl($mosque->slug, $neighbour),
                'published_at' => PostPresenter::iso($neighbour->published_at),
            ];
        };

        return ['previous' => $present($find('older')), 'next' => $present($find('newer'))];
    }
}
