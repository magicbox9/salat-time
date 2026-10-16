<?php

namespace App\Http\Controllers\Manage;

use App\Http\Controllers\Controller;
use App\Http\Controllers\Manage\Support\ImageStore;
use App\Http\Controllers\MosquePage\Support\PostPresenter;
use App\Http\Requests\Manage\SavePostRequest;
use App\Models\Mosque;
use App\Models\MosquePost;
use App\Support\MosquePresenter;
use Carbon\CarbonImmutable;
use Carbon\CarbonInterface;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Pagination\LengthAwarePaginator;
use Illuminate\Support\Facades\Gate;
use Inertia\Inertia;
use Inertia\Response;
use Throwable;

/** Posts on a mosque's page: news, events, announcements and janaza notices. */
class PostController extends Controller
{
    public function index(Request $request, Mosque $mosque): Response
    {
        $status = $request->query('status');
        /** @var LengthAwarePaginator<int, MosquePost> $posts */
        $posts = $mosque->posts()
            ->withCount('comments')
            ->when($status === 'drafts', fn ($q) => $q->whereNull('published_at'))
            ->when($status === 'published', fn ($q) => $q->whereNotNull('published_at'))
            ->orderByRaw('published_at IS NOT NULL')
            ->orderByDesc('pinned')
            ->orderByDesc('published_at')
            ->orderByDesc('id')
            ->paginate(20)
            ->withQueryString();
        $posts->through(fn (MosquePost $post) => [
            ...PostPresenter::post($post),
            'updated_at' => PostPresenter::iso($post->updated_at),
        ]);

        return Inertia::render('manage/posts', [
            'mosque' => MosquePresenter::summary($mosque),
            'posts' => $posts,
            'status' => in_array($status, ['drafts', 'published'], true) ? $status : 'all',
        ]);
    }

    public function create(Mosque $mosque): Response
    {
        return Inertia::render('manage/post-form', [
            'mosque' => MosquePresenter::summary($mosque),
            'post' => null,
            'types' => MosquePost::TYPES,
        ]);
    }

    public function store(SavePostRequest $request, Mosque $mosque, ImageStore $images): RedirectResponse
    {
        $post = new MosquePost(['mosque_id' => $mosque->id, 'author_id' => $request->user()->id]);
        $this->fill($post, $request, $mosque, $images);

        return $this->toIndex($mosque, $post->published_at ? 'manage.post_published' : 'manage.post_saved_draft');
    }

    public function edit(Mosque $mosque, MosquePost $post): Response
    {
        // Besides the route's scoped binding: the post's own mosque must be managed.
        Gate::authorize('update', $post);
        $start = $post->getAttribute('event_starts_at');

        return Inertia::render('manage/post-form', [
            'mosque' => MosquePresenter::summary($mosque),
            'post' => [
                'id' => $post->id,
                'type' => $post->type,
                'title' => $post->title,
                'body' => $post->body,
                'image_url' => PostPresenter::url($post->image_path),
                'event_starts_at' => $start instanceof CarbonInterface
                    ? $start->setTimezone($mosque->timezone)->format('Y-m-d\TH:i')
                    : '',
                'pinned' => (bool) $post->pinned,
                'published' => $post->published_at !== null,
            ],
            'types' => MosquePost::TYPES,
        ]);
    }

    public function update(SavePostRequest $request, Mosque $mosque, MosquePost $post, ImageStore $images): RedirectResponse
    {
        Gate::authorize('update', $post);
        $this->fill($post, $request, $mosque, $images);

        return $this->toIndex($mosque, 'manage.post_updated');
    }

    public function destroy(Mosque $mosque, MosquePost $post, ImageStore $images): RedirectResponse
    {
        Gate::authorize('delete', $post);
        // The record is soft-deleted; the picture goes at once (it may show people).
        $images->delete($mosque, $post->image_path);
        $post->forceFill(['image_path' => null])->save();
        $post->delete();

        return $this->toIndex($mosque, 'manage.post_deleted');
    }

    private function toIndex(Mosque $mosque, string $message): RedirectResponse
    {
        Inertia::flash('toast', ['type' => 'success', 'message' => ui($message)]);

        return to_route('manage.posts.index', $mosque);
    }

    private function fill(MosquePost $post, SavePostRequest $request, Mosque $mosque, ImageStore $images): void
    {
        $data = $request->validated();
        $isEvent = $data['type'] === 'event';
        $publish = $request->boolean('publish');

        $post->fill([
            'type' => $data['type'],
            'title' => $data['title'],
            'body' => $data['body'],
            'pinned' => $request->boolean('pinned'),
            'event_starts_at' => $isEvent && ! empty($data['event_starts_at'])
                ? CarbonImmutable::createFromFormat('Y-m-d\TH:i', $data['event_starts_at'], $mosque->timezone)->utc()
                : null,
            'published_at' => $publish ? ($post->published_at ?? now()) : null,
        ]);

        $old = $post->image_path;
        $stored = null;
        if ($request->hasFile('image')) {
            $post->image_path = $stored = $images->store($mosque, $request->file('image'), 'image', 'posts', 1600);
        } elseif ($request->boolean('remove_image')) {
            $post->image_path = null;
        }

        try {
            $post->save();
        } catch (Throwable $e) {
            $images->delete($mosque, $stored);

            throw $e;
        }

        // The old picture goes only once the post points elsewhere.
        if ($old !== null && $old !== $post->image_path) {
            $images->delete($mosque, $old);
        }
    }
}
