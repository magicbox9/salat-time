<?php

namespace App\Http\Controllers\MosquePage;

use App\Http\Controllers\Controller;
use App\Http\Controllers\MosquePage\Support\FeedCursor;
use App\Http\Controllers\MosquePage\Support\PlainText;
use App\Http\Controllers\MosquePage\Support\PostPresenter;
use App\Models\Mosque;
use App\Models\MosquePost;
use App\Models\PostComment;
use Carbon\CarbonInterface;
use Illuminate\Contracts\Pagination\CursorPaginator;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Gate;
use Inertia\Inertia;

/**
 * Comments under a mosque's posts. Reading is public; writing needs a signed-in
 * visitor with a verified email (route middleware) and is throttled. Hidden
 * comments are shown only to the mosque's managers and admins.
 */
class CommentController extends Controller
{
    private const PER_PAGE = 20;

    public function index(Request $request, Mosque $mosque, MosquePost $post): JsonResponse
    {
        $this->ensurePublished($post);
        $data = $request->validate(['cursor' => ['nullable', 'string', 'max:500']]);
        $user = $request->user();
        $moderator = $user?->can('manage', $mosque) ?? false;
        $from = FeedCursor::decode($data['cursor'] ?? null, ['id' => FeedCursor::ID]);

        /** @var CursorPaginator<int, PostComment> $page */
        $page = $post->comments()
            ->with('user:id,name')
            ->when(! $moderator, fn ($q) => $q->whereNull('hidden_at'))
            ->orderBy('id')
            ->cursorPaginate(self::PER_PAGE, ['*'], 'cursor', $from);

        return response()->json([
            'data' => collect($page->items())
                ->map(fn ($c) => PostPresenter::comment($c, $user, $moderator))
                ->values()
                ->all(),
            'next_cursor' => $page->nextCursor()?->encode(),
        ]);
    }

    public function store(Request $request, Mosque $mosque, MosquePost $post): JsonResponse|RedirectResponse
    {
        $this->ensurePublished($post);
        $data = $request->validate([
            'body' => ['required', 'string', PlainText::RULE, 'min:2', 'max:1000'],
        ]);
        $user = $request->user();

        /** @var PostComment $comment */
        $comment = $post->comments()->create([
            'user_id' => $user->id,
            'body' => $data['body'],
        ]);
        $comment->setRelation('user', $user);

        if ($request->wantsJson()) {
            return response()->json([
                'comment' => PostPresenter::comment($comment, $user, $user->can('manage', $mosque)),
            ], 201);
        }

        return Inertia::flash('toast', ['type' => 'success', 'message' => ui('mosque.comment_posted')])->back();
    }

    public function destroy(Request $request, PostComment $comment): JsonResponse|RedirectResponse
    {
        Gate::authorize('delete', $comment);
        $comment->delete();

        if ($request->wantsJson()) {
            return response()->json(['deleted' => true]);
        }

        return Inertia::flash('toast', ['type' => 'success', 'message' => ui('mosque.comment_deleted')])->back();
    }

    /** Drafts and scheduled posts do not exist for the public. */
    private function ensurePublished(MosquePost $post): void
    {
        $published = $post->getAttribute('published_at');
        abort_unless($published instanceof CarbonInterface && ! $published->isFuture(), 404);
    }
}
