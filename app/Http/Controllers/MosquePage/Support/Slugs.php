<?php

namespace App\Http\Controllers\MosquePage\Support;

use App\Models\MosquePost;
use Illuminate\Database\UniqueConstraintViolationException;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;

/**
 * Addresses of a mosque's posts and pages: lowercase ASCII words joined by
 * hyphens ("cours-de-tajwid"), unique within the mosque. Titles in Arabic
 * are transliterated. Soft-deleted rows still hold their slug in the unique
 * index, so they are counted as taken.
 */
final class Slugs
{
    /** What a slug looks like, for routes and validation. */
    public const PATTERN = '[a-z0-9]+(?:-[a-z0-9]+)*';

    public const RULE = 'regex:/^'.self::PATTERN.'$/';

    public const POST_MAX = 200;

    public const PAGE_MAX = 160;

    public static function base(string $title, string $fallback, int $max): string
    {
        $slug = trim(substr(Str::slug(Str::limit($title, 400, '')), 0, $max), '-');

        return $slug !== '' ? $slug : $fallback;
    }

    /** $base, or $base-2, $base-3… whichever no other row of the mosque uses. */
    public static function unique(string $table, int $mosqueId, string $base, ?int $ignoreId, int $max): string
    {
        $taken = DB::table($table)
            ->where('mosque_id', $mosqueId)
            ->where(fn ($q) => $q->where('slug', $base)
                ->orWhere('slug', 'like', addcslashes($base, '%_\\').'-%'))
            ->when($ignoreId !== null, fn ($q) => $q->where('id', '!=', $ignoreId))
            ->pluck('slug')
            ->flip()
            ->all();

        if (! isset($taken[$base])) {
            return $base;
        }

        for ($i = 2; ; $i++) {
            $suffix = '-'.$i;
            $candidate = rtrim(substr($base, 0, $max - strlen($suffix)), '-').$suffix;
            if (! isset($taken[$candidate])) {
                return $candidate;
            }
        }
    }

    /**
     * Gives an address to posts that have none yet (written by another part
     * of the app, or before the blog existed). Runs once per post.
     *
     * @param  iterable<MosquePost>  $posts
     */
    public static function ensureForPosts(iterable $posts): void
    {
        foreach ($posts as $post) {
            if ($post->slug) {
                continue;
            }

            for ($attempt = 0; $attempt < 3 && ! $post->slug; $attempt++) {
                $slug = self::unique('mosque_posts', $post->mosque_id,
                    self::base((string) $post->title, 'post', self::POST_MAX), $post->id, self::POST_MAX);

                try {
                    // Without touching updated_at: giving an address is not an edit. In its own
                    // savepoint, so a refused write leaves any enclosing transaction usable.
                    $written = DB::transaction(fn () => MosquePost::withTrashed()->whereKey($post->id)->whereNull('slug')
                        ->toBase()->update(['slug' => $slug]));
                } catch (UniqueConstraintViolationException) {
                    continue;   // another request took this slug a moment ago: try the next one
                }

                $post->slug = $written > 0
                    ? $slug
                    : MosquePost::withTrashed()->whereKey($post->id)->value('slug');
                $post->syncOriginalAttribute('slug');
            }
        }
    }

    /** Frees the address of a deleted row (live slugs never contain a dot). */
    public static function retired(string $slug, int $id, int $max): string
    {
        $suffix = '.deleted.'.$id;

        return substr($slug, 0, $max - strlen($suffix)).$suffix;
    }
}
