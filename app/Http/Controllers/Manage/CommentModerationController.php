<?php

namespace App\Http\Controllers\Manage;

use App\Http\Controllers\Controller;
use App\Http\Controllers\MosquePage\Support\PostPresenter;
use App\Models\Mosque;
use App\Models\MosquePost;
use App\Models\PostComment;
use App\Support\MosquePresenter;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Gate;
use Inertia\Inertia;
use Inertia\Response;

/**
 * Comment moderation. Hidden comments stay in the database for the record and
 * disappear from the public page; a manager can bring them back.
 */
class CommentModerationController extends Controller
{
    public function index(Request $request, Mosque $mosque): Response
    {
        $filter = $request->query('filter') === 'hidden' ? 'hidden' : 'all';
        $user = $request->user();

        $comments = PostComment::query()
            ->whereIn('post_id', MosquePost::query()->select('id')->where('mosque_id', $mosque->id))
            ->with(['user:id,name', 'post:id,title'])
            ->when($filter === 'hidden', fn ($q) => $q->whereNotNull('hidden_at'))
            ->orderByDesc('id')
            ->paginate(25)
            ->withQueryString()
            ->through(fn (PostComment $comment) => [
                ...PostPresenter::comment($comment, $user, true),
                'post' => ['id' => $comment->post_id, 'title' => (string) $comment->post?->getAttribute('title')],
            ]);

        return Inertia::render('manage/comments', [
            'mosque' => MosquePresenter::summary($mosque),
            'comments' => $comments,
            'filter' => $filter,
        ]);
    }

    public function hide(Request $request, PostComment $comment): JsonResponse|RedirectResponse
    {
        Gate::authorize('moderate', $comment);
        $comment->forceFill(['hidden_at' => now(), 'hidden_by' => $request->user()->id])->save();

        return $this->respond($request, $comment, 'manage.comment_hidden');
    }

    public function unhide(Request $request, PostComment $comment): JsonResponse|RedirectResponse
    {
        Gate::authorize('moderate', $comment);
        $comment->forceFill(['hidden_at' => null, 'hidden_by' => null])->save();

        return $this->respond($request, $comment, 'manage.comment_restored');
    }

    private function respond(Request $request, PostComment $comment, string $message): JsonResponse|RedirectResponse
    {
        if ($request->wantsJson()) {
            $comment->load('user:id,name');

            return response()->json(['comment' => PostPresenter::comment($comment, $request->user(), true)]);
        }

        return Inertia::flash('toast', ['type' => 'success', 'message' => ui($message)])->back();
    }
}
