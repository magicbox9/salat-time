<?php

namespace App\Http\Controllers\Manage;

use App\Http\Controllers\Controller;
use App\Http\Controllers\Manage\Support\DefaultCategories;
use App\Http\Controllers\Manage\Support\PostWriter;
use App\Http\Controllers\MosquePage\Support\ArticlePresenter;
use App\Http\Controllers\MosquePage\Support\BlogPosts;
use App\Http\Controllers\MosquePage\Support\PostPresenter;
use App\Http\Requests\Manage\SavePostRequest;
use App\Models\Mosque;
use App\Models\MosquePost;
use App\Models\MosquePostCategory;
use App\Support\MosquePresenter;
use Carbon\CarbonInterface;
use Illuminate\Database\Eloquent\Collection;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Pagination\LengthAwarePaginator;
use Illuminate\Support\Facades\Gate;
use Inertia\Inertia;
use Inertia\Response;

/** The posts of a mosque's blog: khutbahs, news, events, announcements, janaza notices. */
class PostController extends Controller
{
    private const FILTERS = ['published', 'scheduled', 'drafts'];

    public function index(Request $request, Mosque $mosque, DefaultCategories $defaults): Response
    {
        $defaults->ensure($mosque, $request->user());
        $status = $request->query('status');
        $status = in_array($status, self::FILTERS, true) ? $status : 'all';

        /** @var LengthAwarePaginator<int, MosquePost> $posts */
        $posts = $mosque->posts()
            ->with('category:id,name,slug')
            ->withCount('comments')
            ->when($status === 'drafts', fn ($q) => $q->whereNull('published_at'))
            ->when($status === 'scheduled', fn ($q) => $q->where('published_at', '>', now()))
            ->when($status === 'published', fn ($q) => $q->where('published_at', '<=', now()))
            ->orderByRaw('published_at IS NOT NULL')
            ->orderByDesc('published_at')
            ->orderByDesc('id')
            ->paginate(20)
            ->withQueryString();
        $posts->through(fn (MosquePost $post) => [
            ...PostPresenter::post($post, $mosque->slug),
            'category' => PostPresenter::category($post),
            'status' => BlogPosts::status($post),
            'updated_at' => PostPresenter::iso($post->updated_at),
        ]);

        return Inertia::render('manage/posts', [
            'mosque' => MosquePresenter::summary($mosque),
            'posts' => $posts,
            'status' => $status,
        ]);
    }

    public function create(Request $request, Mosque $mosque, DefaultCategories $defaults): Response
    {
        $defaults->ensure($mosque, $request->user());

        return Inertia::render('manage/post-form', [
            'mosque' => MosquePresenter::summary($mosque),
            'post' => null,
            ...$this->formOptions($mosque),
        ]);
    }

    public function store(SavePostRequest $request, Mosque $mosque, PostWriter $writer): RedirectResponse
    {
        $post = new MosquePost(['mosque_id' => $mosque->id, 'author_id' => $request->user()->id]);
        $writer->save($post, $request, $mosque);

        return $this->toIndex($mosque, match (BlogPosts::status($post)) {
            'published' => 'manage.post_published',
            'scheduled' => 'manage.post_scheduled',
            default => 'manage.post_saved_draft',
        });
    }

    public function edit(Request $request, Mosque $mosque, MosquePost $post, DefaultCategories $defaults): Response
    {
        // Besides the route's scoped binding: the post's own mosque must be managed.
        Gate::authorize('update', $post);
        $defaults->ensure($mosque, $request->user());
        $local = fn (mixed $at) => $at instanceof CarbonInterface ? $at->setTimezone($mosque->timezone)->format('Y-m-d\TH:i') : '';
        $status = BlogPosts::status($post);

        return Inertia::render('manage/post-form', [
            'mosque' => MosquePresenter::summary($mosque),
            'post' => [
                'id' => $post->id,
                'type' => $post->type,
                'category_id' => $post->category_id,
                'title' => $post->title,
                'slug' => (string) $post->slug,
                'excerpt' => (string) $post->excerpt,
                'body' => $post->body,
                'image_url' => PostPresenter::url($post->image_path),
                'video_url' => (string) $post->video_url,
                'attachment' => ArticlePresenter::attachment($post),
                'event_starts_at' => $local($post->getAttribute('event_starts_at')),
                'pinned' => (bool) $post->pinned,
                'status' => $status,
                'publish_at' => $status === 'scheduled' ? $local($post->getAttribute('published_at')) : '',
                'published' => $status === 'published',
                'url' => PostPresenter::articleUrl($mosque->slug, $post),
            ],
            ...$this->formOptions($mosque),
        ]);
    }

    public function update(SavePostRequest $request, Mosque $mosque, MosquePost $post, PostWriter $writer): RedirectResponse
    {
        Gate::authorize('update', $post);
        $writer->save($post, $request, $mosque);

        return $this->toIndex($mosque, 'manage.post_updated');
    }

    public function destroy(Mosque $mosque, MosquePost $post, PostWriter $writer): RedirectResponse
    {
        Gate::authorize('delete', $post);
        // The record is soft-deleted; its files go at once (a picture may show people).
        $writer->delete($post, $mosque);

        return $this->toIndex($mosque, 'manage.post_deleted');
    }

    /** @return array<string, mixed> */
    private function formOptions(Mosque $mosque): array
    {
        /** @var Collection<int, MosquePostCategory> $categories */
        $categories = $mosque->postCategories()->get(['id', 'name', 'slug']);

        return [
            'types' => MosquePost::TYPES,
            'categories' => $categories
                ->map(fn (MosquePostCategory $c) => ['id' => $c->id, 'name' => $c->name, 'slug' => $c->slug])
                ->values()
                ->all(),
            'limits' => ['body' => SavePostRequest::BODY_MAX, 'attachment_mb' => 10],
        ];
    }

    private function toIndex(Mosque $mosque, string $message): RedirectResponse
    {
        Inertia::flash('toast', ['type' => 'success', 'message' => ui($message)]);

        return to_route('manage.posts.index', $mosque);
    }
}
