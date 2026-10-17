<?php

namespace App\Http\Controllers\Manage;

use App\Http\Controllers\Controller;
use App\Http\Controllers\Manage\Support\DefaultCategories;
use App\Http\Controllers\MosquePage\Support\BlogPosts;
use App\Http\Controllers\MosquePage\Support\PostPresenter;
use App\Http\Controllers\MosquePage\Support\SocialLinks;
use App\Models\Mosque;
use App\Models\MosquePost;
use App\Models\PostComment;
use App\Support\MosquePresenter;
use Illuminate\Database\Eloquent\Collection;
use Illuminate\Http\Request;
use Inertia\Inertia;
use Inertia\Response;

/** The first page of a mosque's management: where things stand, what to do next. */
class ManageOverviewController extends Controller
{
    public function __invoke(Request $request, Mosque $mosque, DefaultCategories $defaults): Response
    {
        $defaults->ensure($mosque, $request->user());
        $now = now();
        $posts = $mosque->posts()
            ->toBase()
            ->selectRaw('count(*) filter (where published_at is not null and published_at <= ?) as published', [$now])
            ->selectRaw('count(*) filter (where published_at > ?) as scheduled', [$now])
            ->selectRaw('count(*) filter (where published_at is null) as drafts')
            ->selectRaw('count(*) filter (where published_at is not null and published_at <= ? and category_id in (select id from mosque_post_categories where mosque_id = ? and slug = ?)) as khutbahs', [$now, $mosque->id, BlogPosts::KHUTBAH])
            ->first();
        $comments = PostComment::query()
            ->whereIn('post_id', MosquePost::query()->select('id')->where('mosque_id', $mosque->id))
            ->toBase()
            ->selectRaw('count(*) as total')
            ->selectRaw('count(*) filter (where hidden_at is not null) as hidden')
            ->selectRaw('count(*) filter (where created_at >= ?) as recent', [$now->subDays(7)])
            ->first();
        /** @var Collection<int, MosquePost> $recent */
        $recent = $mosque->posts()
            ->with('category:id,name,slug')
            ->orderByDesc('updated_at')
            ->orderByDesc('id')
            ->limit(5)
            ->get();
        $pages = $mosque->pages()->toBase()
            ->selectRaw('count(*) as total')
            ->selectRaw('count(*) filter (where published_at is not null) as published')
            ->first();

        return Inertia::render('manage/overview', [
            'mosque' => [
                ...MosquePresenter::summary($mosque),
                'cover_url' => PostPresenter::url($mosque->cover_path),
                'tagline' => $mosque->tagline,
            ],
            'stats' => [
                'published' => (int) ($posts->published ?? 0),
                'scheduled' => (int) ($posts->scheduled ?? 0),
                'drafts' => (int) ($posts->drafts ?? 0),
                'pages' => (int) ($pages->total ?? 0),
                'categories' => $mosque->postCategories()->count(),
                'comments' => (int) ($comments->total ?? 0),
                'comments_hidden' => (int) ($comments->hidden ?? 0),
                'comments_recent' => (int) ($comments->recent ?? 0),
            ],
            'checklist' => [
                'logo' => $mosque->logo_path !== null,
                'cover' => $mosque->cover_path !== null,
                'tagline' => filled($mosque->tagline),
                'description' => filled($mosque->description),
                'contact' => filled($mosque->phone) || filled($mosque->email),
                'social' => SocialLinks::present($mosque->social_links) !== [],
                'page' => (int) ($pages->published ?? 0) > 0,
                'khutbah' => (int) ($posts->khutbahs ?? 0) > 0,
            ],
            'recent' => $recent
                ->map(fn (MosquePost $post) => [
                    'id' => $post->id,
                    'title' => $post->title,
                    'category' => PostPresenter::category($post),
                    'status' => BlogPosts::status($post),
                    'published_at' => PostPresenter::iso($post->published_at),
                    'updated_at' => PostPresenter::iso($post->updated_at),
                ])
                ->values()
                ->all(),
            'isAdmin' => (bool) $request->user()->is_admin,
        ]);
    }
}
