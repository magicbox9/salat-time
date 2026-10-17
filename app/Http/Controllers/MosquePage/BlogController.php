<?php

namespace App\Http\Controllers\MosquePage;

use App\Http\Controllers\Controller;
use App\Http\Controllers\MosquePage\Support\ArticlePresenter;
use App\Http\Controllers\MosquePage\Support\BlogPosts;
use App\Http\Controllers\MosquePage\Support\MosqueProfile;
use App\Http\Controllers\MosquePage\Support\MosqueSite;
use App\Http\Controllers\MosquePage\Support\PostPresenter;
use App\Http\Controllers\MosquePage\Support\Slugs;
use App\Models\Mosque;
use App\Models\MosquePost;
use App\Models\MosquePostCategory;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Collection;
use Illuminate\Http\Request;
use Illuminate\Pagination\LengthAwarePaginator;
use Inertia\Inertia;
use Inertia\Response;

/** A mosque's blog: the list (by category, searchable) and each article. */
class BlogController extends Controller
{
    private const PER_PAGE = 12;

    public function index(Request $request, Mosque $mosque): Response
    {
        $search = $this->searchTerm($request->query('q'));
        /** @var Collection<int, MosquePostCategory> $categories */
        $categories = $mosque->postCategories()
            ->withCount(['posts' => fn (Builder $q) => $q->whereNotNull('published_at')->where('published_at', '<=', now())])
            ->get(['id', 'mosque_id', 'name', 'slug', 'description', 'sort']);
        $wanted = $request->query('category');
        /** @var MosquePostCategory|null $category */
        $category = is_string($wanted) ? $categories->firstWhere('slug', $wanted) : null;

        /** @var LengthAwarePaginator<int, MosquePost> $posts */
        $posts = BlogPosts::published($mosque)
            ->with('category:id,name,slug')
            ->withCount(['comments' => fn (Builder $q) => $q->whereNull('hidden_at')])
            ->when($category, fn ($q) => $q->where('category_id', $category->id))
            ->when($search !== '', function ($q) use ($search) {
                $like = '%'.addcslashes($search, '%_\\').'%';
                $q->where(fn ($q) => $q->where('title', 'ilike', $like)
                    ->orWhere('excerpt', 'ilike', $like)
                    ->orWhere('body', 'ilike', $like));
            })
            ->orderByDesc('published_at')
            ->orderByDesc('id')
            ->paginate(self::PER_PAGE)
            ->withQueryString();
        Slugs::ensureForPosts($posts->items());
        $posts->through(fn (MosquePost $post) => PostPresenter::card($post, $mosque));
        $url = route('mosques.blog', $mosque);

        return Inertia::render('mosques/blog', [
            'site' => fn () => MosqueSite::shell($mosque),
            'categories' => $categories->map(fn (MosquePostCategory $c) => [
                'id' => $c->id,
                'name' => $c->name,
                'slug' => $c->slug,
                'description' => $c->description,
                'posts_count' => (int) $c->getAttribute('posts_count'),
            ])->values()->all(),
            'filters' => ['category' => $category?->slug, 'q' => $search],
            'activeCategory' => $category ? ['name' => $category->name, 'description' => $category->description] : null,
            'posts' => $posts,
            'canManage' => (bool) $request->user()?->can('manage', $mosque),
            'meta' => MosqueSite::meta(
                $category ? $category->name.' · '.$mosque->name : ui('mosquesite.blog_title_of', ['name' => $mosque->name]),
                $category?->description ?: ui('mosquesite.meta_blog', ['name' => $mosque->name]),
                PostPresenter::url($mosque->cover_path),
                $category ? $url.'?category='.$category->slug : $url,
            ),
        ]);
    }

    public function show(Request $request, Mosque $mosque, string $postSlug): Response
    {
        $user = $request->user();
        $canManage = $user?->can('manage', $mosque) ?? false;

        /** @var MosquePost $post */
        $post = $mosque->posts()
            ->where('slug', $postSlug)
            ->with(['category:id,name,slug', 'author:id,name'])
            ->withCount(['comments' => fn (Builder $q) => $canManage ? $q : $q->whereNull('hidden_at')])
            ->firstOrFail();

        // Drafts and scheduled posts exist only for the mosque's managers (a preview).
        abort_unless(BlogPosts::isPublic($post) || $canManage, 404);

        $url = route('mosques.blog.show', [$mosque, $post->slug]);

        return Inertia::render('mosques/post', [
            'site' => fn () => MosqueSite::shell($mosque),
            'post' => ArticlePresenter::article($post, $mosque),
            'neighbours' => fn () => ArticlePresenter::neighbours($post, $mosque),
            'viewer' => fn () => MosqueProfile::viewer($user, $mosque, $canManage),
            'shareUrl' => $url,
            'meta' => MosqueSite::meta(
                $post->title.' · '.$mosque->name,
                $post->excerpt ?: $post->body,
                PostPresenter::url($post->image_path ?? $mosque->cover_path),
                $url,
                'article',
            ),
        ]);
    }

    /** The search box: trimmed, at most 100 characters, clean UTF-8 only. */
    private function searchTerm(mixed $value): string
    {
        if (! is_string($value) || ! mb_check_encoding($value, 'UTF-8') || str_contains($value, "\0")) {
            return '';
        }

        return mb_substr(trim(preg_replace('/\s+/u', ' ', $value) ?? ''), 0, 100);
    }
}
