<?php

namespace App\Http\Controllers\MosquePage\Support;

use App\Models\Mosque;
use App\Models\MosquePost;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Validation\ValidationException;

/**
 * A mosque's public feed: pinned posts first, then the others, newest first,
 * one cursor page at a time. Drafts and future posts never appear.
 */
class PostFeed
{
    public const PER_PAGE = 10;

    public const MAX_PINNED = 6;

    /** @return array<int, array<string, mixed>> */
    public function pinned(Mosque $mosque, bool $moderator): array
    {
        return $this->published($mosque, $moderator)
            ->where('pinned', true)
            ->orderByDesc('published_at')
            ->orderByDesc('id')
            ->limit(self::MAX_PINNED)
            ->get()
            ->map(fn (MosquePost $post) => PostPresenter::post($post))
            ->values()
            ->all();
    }

    /**
     * @return array{data: array<int, array<string, mixed>>, next_cursor: string|null}
     *
     * @throws ValidationException on a forged cursor
     */
    public function page(Mosque $mosque, ?string $cursor, bool $moderator): array
    {
        $from = FeedCursor::decode($cursor, ['published_at' => FeedCursor::TIMESTAMP, 'id' => FeedCursor::ID]);
        $pinnedIds = $this->published($mosque, false)
            ->where('pinned', true)
            ->orderByDesc('published_at')
            ->orderByDesc('id')
            ->limit(self::MAX_PINNED)
            ->pluck('id');

        $page = $this->published($mosque, $moderator)
            ->whereNotIn('id', $pinnedIds)
            ->orderByDesc('published_at')
            ->orderByDesc('id')
            ->cursorPaginate(self::PER_PAGE, ['*'], 'cursor', $from);

        return [
            'data' => collect($page->items())->map(fn (MosquePost $post) => PostPresenter::post($post))->values()->all(),
            'next_cursor' => $page->nextCursor()?->encode(),
        ];
    }

    /**
     * Published posts with their comment count (hidden comments count only for moderators).
     *
     * @return HasMany<MosquePost, Mosque>
     */
    private function published(Mosque $mosque, bool $moderator): HasMany
    {
        return $mosque->posts()
            ->whereNotNull('published_at')
            ->where('published_at', '<=', now())
            ->withCount(['comments' => fn (Builder $q) => $moderator ? $q : $q->whereNull('hidden_at')]);
    }
}
