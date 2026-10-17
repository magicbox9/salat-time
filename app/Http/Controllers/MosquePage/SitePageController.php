<?php

namespace App\Http\Controllers\MosquePage;

use App\Http\Controllers\Controller;
use App\Http\Controllers\MosquePage\Support\MosqueSite;
use App\Http\Controllers\MosquePage\Support\PostPresenter;
use App\Models\Mosque;
use App\Models\MosquePage;
use App\Support\Markdown;
use Carbon\CarbonInterface;
use Illuminate\Http\Request;
use Inertia\Inertia;
use Inertia\Response;

/** A static page of a mosque's site (About us, Courses, Contact…). */
class SitePageController extends Controller
{
    public function __invoke(Request $request, Mosque $mosque, string $pageSlug): Response
    {
        /** @var MosquePage $page */
        $page = $mosque->pages()->where('slug', $pageSlug)->firstOrFail();
        $publishedAt = $page->getAttribute('published_at');
        $public = $publishedAt instanceof CarbonInterface && ! $publishedAt->isFuture();
        $canManage = (bool) $request->user()?->can('manage', $mosque);

        // Unpublished pages exist only for the mosque's managers (a preview).
        abort_unless($public || $canManage, 404);

        $url = route('mosques.pages.show', [$mosque, $page->slug]);

        return Inertia::render('mosques/page', [
            'site' => fn () => MosqueSite::shell($mosque),
            'page' => [
                'id' => $page->id,
                'title' => $page->title,
                'slug' => $page->slug,
                'body_html' => Markdown::toHtml($page->body),
                'updated_at' => PostPresenter::iso($page->updated_at),
                'published' => $public,
            ],
            'canManage' => $canManage,
            'shareUrl' => $url,
            'meta' => MosqueSite::meta(
                $page->title.' · '.$mosque->name,
                $page->body,
                PostPresenter::url($mosque->cover_path),
                $url,
            ),
        ]);
    }
}
