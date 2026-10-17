<?php

namespace App\Http\Controllers\Manage\Support;

use App\Http\Controllers\MosquePage\Support\BlogPosts;
use App\Models\Mosque;
use App\Models\MosquePostCategory;
use App\Models\User;
use Illuminate\Support\Facades\DB;

/**
 * The first time a mosque's managers open their blog tools, the mosque gets
 * the usual categories, named in the manager's language. This happens once:
 * categories deleted afterwards do not come back. An admin looking around
 * another mosque's management does not trigger it (the names would be in
 * the admin's language, not the mosque's).
 */
class DefaultCategories
{
    /** slug => translation key */
    public const DEFAULTS = [
        BlogPosts::KHUTBAH => 'manage.category_default_khutbah',
        'news' => 'manage.category_default_news',
        'events' => 'manage.category_default_events',
        'education' => 'manage.category_default_education',
        'announcements' => 'manage.category_default_announcements',
    ];

    public function ensure(Mosque $mosque, ?User $visitor): void
    {
        if ($mosque->getAttribute('post_categories_seeded_at') !== null || ! $visitor?->manages($mosque)) {
            return;
        }

        DB::transaction(function () use ($mosque): void {
            // Locked: two tabs opened at once must not seed twice.
            $fresh = Mosque::query()->whereKey($mosque->id)->lockForUpdate()->first(['id', 'post_categories_seeded_at']);
            if (! $fresh || $fresh->getAttribute('post_categories_seeded_at') !== null) {
                return;
            }

            if (! MosquePostCategory::query()->where('mosque_id', $mosque->id)->exists()) {
                $sort = 0;
                foreach (self::DEFAULTS as $slug => $key) {
                    MosquePostCategory::query()->create([
                        'mosque_id' => $mosque->id,
                        'name' => ui($key),
                        'slug' => $slug,
                        'sort' => $sort++,
                    ]);
                }
            }

            Mosque::query()->whereKey($mosque->id)->toBase()->update(['post_categories_seeded_at' => now()]);
        });

        $mosque->setAttribute('post_categories_seeded_at', now());
        $mosque->syncOriginalAttribute('post_categories_seeded_at');
    }
}
