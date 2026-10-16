<?php

namespace App\Http\Controllers\Manage;

use App\Http\Controllers\Controller;
use App\Models\Mosque;
use App\Models\PostComment;
use App\Support\MosquePresenter;
use Illuminate\Database\Eloquent\Collection;
use Illuminate\Http\Request;
use Inertia\Inertia;
use Inertia\Response;

/** "Mosques I manage": the entry point of the management area. */
class ManageIndexController extends Controller
{
    public function __invoke(Request $request): Response
    {
        /** @var Collection<int, Mosque> $mosques */
        $mosques = $request->user()->managedMosques()
            ->withCount([
                'calendars',
                'posts as published_count' => fn ($q) => $q->whereNotNull('published_at'),
                'posts as drafts_count' => fn ($q) => $q->whereNull('published_at'),
            ])
            ->orderBy('name')
            ->get();

        $commentCounts = PostComment::query()
            ->join('mosque_posts', 'mosque_posts.id', '=', 'post_comments.post_id')
            ->whereIn('mosque_posts.mosque_id', $mosques->modelKeys())
            ->whereNull('mosque_posts.deleted_at')
            ->selectRaw('mosque_posts.mosque_id, count(*) as total')
            ->groupBy('mosque_posts.mosque_id')
            ->pluck('total', 'mosque_posts.mosque_id');

        return Inertia::render('manage/index', [
            'mosques' => $mosques->map(fn (Mosque $mosque) => [
                ...MosquePresenter::summary($mosque),
                'role' => (string) $mosque->getRelation('pivot')->getAttribute('role'),
                'published_count' => (int) $mosque->getAttribute('published_count'),
                'drafts_count' => (int) $mosque->getAttribute('drafts_count'),
                'comments_count' => (int) ($commentCounts[$mosque->id] ?? 0),
            ])->values()->all(),
            'isAdmin' => (bool) $request->user()->is_admin,
        ]);
    }
}
