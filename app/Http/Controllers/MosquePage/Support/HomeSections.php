<?php

namespace App\Http\Controllers\MosquePage\Support;

use App\Models\Mosque;
use App\Models\MosquePage;
use App\Models\MosquePost;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Collection;
use Illuminate\Database\Eloquent\Relations\HasMany;

/**
 * The blog pieces of a mosque's home page: the pinned announcement, the
 * latest posts of each category and the upcoming events.
 */
final class HomeSections
{
    private const PINNED = 3;

    private const RECENT = 24;

    private const PER_CATEGORY = 3;

    private const GROUPS = 5;

    private const EVENTS = 4;

    /** @return array<int, array<string, mixed>> */
    public static function pinned(Mosque $mosque): array
    {
        return self::cards($mosque, self::query($mosque)
            ->where('pinned', true)
            ->orderByDesc('published_at')
            ->orderByDesc('id')
            ->limit(self::PINNED)
            ->get());
    }

    /**
     * The newest posts, grouped by category in the mosque's category order
     * (posts without a category last).
     *
     * @return array<int, array{category: array{id: int, name: string, slug: string}|null, posts: array<int, array<string, mixed>>}>
     */
    public static function latestByCategory(Mosque $mosque): array
    {
        $posts = self::query($mosque)
            ->with('category:id,name,slug,sort')
            ->orderByDesc('published_at')
            ->orderByDesc('id')
            ->limit(self::RECENT)
            ->get();
        Slugs::ensureForPosts($posts);

        return $posts
            ->groupBy(fn (MosquePost $post) => (int) $post->category_id)
            ->sortBy(fn (Collection $group, int $id) => $id === 0
                ? [PHP_INT_MAX, 0]
                : [(int) $group->first()->getRelation('category')?->getAttribute('sort'), $id])
            ->take(self::GROUPS)
            ->map(fn (Collection $group) => [
                'category' => PostPresenter::category($group->first()),
                'posts' => $group->take(self::PER_CATEGORY)
                    ->map(fn (MosquePost $post) => PostPresenter::card($post, $mosque))
                    ->values()
                    ->all(),
            ])
            ->values()
            ->all();
    }

    /** @return array<int, array<string, mixed>> */
    public static function upcomingEvents(Mosque $mosque): array
    {
        return self::cards($mosque, self::query($mosque)
            ->where('event_starts_at', '>=', now())
            ->orderBy('event_starts_at')
            ->orderBy('id')
            ->limit(self::EVENTS)
            ->get());
    }

    /** @return array{title: string, slug: string}|null */
    public static function aboutPage(Mosque $mosque): ?array
    {
        /** @var MosquePage|null $page */
        $page = $mosque->pages()
            ->whereNotNull('published_at')
            ->where('published_at', '<=', now())
            ->whereIn('slug', MosqueSite::ABOUT_SLUGS)
            ->orderBy('sort')
            ->first(['id', 'title', 'slug']);

        return $page ? ['title' => $page->title, 'slug' => $page->slug] : null;
    }

    /** @return HasMany<MosquePost, Mosque> */
    private static function query(Mosque $mosque)
    {
        return BlogPosts::published($mosque)
            ->with('category:id,name,slug')
            ->withCount(['comments' => fn (Builder $q) => $q->whereNull('hidden_at')]);
    }

    /**
     * @param  Collection<int, MosquePost>  $posts
     * @return array<int, array<string, mixed>>
     */
    private static function cards(Mosque $mosque, Collection $posts): array
    {
        Slugs::ensureForPosts($posts);

        return $posts->map(fn (MosquePost $post) => PostPresenter::card($post, $mosque))->values()->all();
    }
}
