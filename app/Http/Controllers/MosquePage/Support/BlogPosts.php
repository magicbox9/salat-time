<?php

namespace App\Http\Controllers\MosquePage\Support;

use App\Models\Mosque;
use App\Models\MosquePost;
use Carbon\CarbonInterface;
use Illuminate\Database\Eloquent\Relations\HasMany;

/**
 * What the public may read of a mosque's blog: posts whose publication time
 * has come. Drafts (no date) and scheduled posts (a future date) stay hidden.
 */
final class BlogPosts
{
    /** Slug of the default category of Friday sermons (the "Khutbahs" menu entry). */
    public const KHUTBAH = 'khutbah';

    /** @return HasMany<MosquePost, Mosque> */
    public static function published(Mosque $mosque): HasMany
    {
        return $mosque->posts()
            ->whereNotNull('published_at')
            ->where('published_at', '<=', now());
    }

    public static function isPublic(MosquePost $post): bool
    {
        $at = $post->getAttribute('published_at');

        return $at instanceof CarbonInterface && ! $at->isFuture();
    }

    /** "published", "scheduled" or "draft". */
    public static function status(MosquePost $post): string
    {
        $at = $post->getAttribute('published_at');

        return match (true) {
            ! $at instanceof CarbonInterface => 'draft',
            $at->isFuture() => 'scheduled',
            default => 'published',
        };
    }
}
