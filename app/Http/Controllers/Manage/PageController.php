<?php

namespace App\Http\Controllers\Manage;

use App\Http\Controllers\Controller;
use App\Http\Controllers\MosquePage\Support\PostPresenter;
use App\Http\Controllers\MosquePage\Support\Slugs;
use App\Http\Requests\Manage\SavePageRequest;
use App\Models\Mosque;
use App\Models\MosquePage;
use App\Support\MosquePresenter;
use Carbon\CarbonInterface;
use Illuminate\Database\Eloquent\Collection;
use Illuminate\Database\UniqueConstraintViolationException;
use Illuminate\Http\RedirectResponse;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Gate;
use Illuminate\Validation\ValidationException;
use Inertia\Inertia;
use Inertia\Response;

/** Static pages of a mosque's site (About us, Courses, Contact…). */
class PageController extends Controller
{
    public const MAX = 50;

    public function index(Mosque $mosque): Response
    {
        /** @var Collection<int, MosquePage> $pages */
        $pages = $mosque->pages()
            ->orderBy('sort')
            ->orderBy('title')
            ->get(['id', 'mosque_id', 'title', 'slug', 'sort', 'show_in_menu', 'published_at', 'updated_at']);

        return Inertia::render('manage/pages', [
            'mosque' => MosquePresenter::summary($mosque),
            'pages' => $pages
                ->map(fn (MosquePage $page) => [
                    ...$this->summary($page),
                    'url' => "/mosques/{$mosque->slug}/pages/{$page->slug}",
                    'updated_at' => PostPresenter::iso($page->updated_at),
                ])
                ->values()
                ->all(),
            'max' => self::MAX,
        ]);
    }

    public function create(Mosque $mosque): Response
    {
        return Inertia::render('manage/page-form', [
            'mosque' => MosquePresenter::summary($mosque),
            'page' => null,
            'nextSort' => (int) $mosque->pages()->max('sort') + 1,
            'limits' => ['body' => SavePageRequest::BODY_MAX],
        ]);
    }

    public function store(SavePageRequest $request, Mosque $mosque): RedirectResponse
    {
        if ($mosque->pages()->count() >= self::MAX) {
            throw ValidationException::withMessages(['title' => ui('manage.pages_full', ['max' => self::MAX])]);
        }

        $page = new MosquePage(['mosque_id' => $mosque->id, 'author_id' => $request->user()->id]);
        $this->fill($page, $request, $mosque);

        return $this->toIndex($mosque, 'manage.page_created');
    }

    public function edit(Mosque $mosque, MosquePage $page): Response
    {
        Gate::authorize('update', $page);

        return Inertia::render('manage/page-form', [
            'mosque' => MosquePresenter::summary($mosque),
            'page' => [
                ...$this->summary($page),
                'body' => $page->body,
                'url' => "/mosques/{$mosque->slug}/pages/{$page->slug}",
            ],
            'nextSort' => $page->sort,
            'limits' => ['body' => SavePageRequest::BODY_MAX],
        ]);
    }

    public function update(SavePageRequest $request, Mosque $mosque, MosquePage $page): RedirectResponse
    {
        Gate::authorize('update', $page);
        $this->fill($page, $request, $mosque);

        return $this->toIndex($mosque, 'manage.page_updated');
    }

    public function destroy(Mosque $mosque, MosquePage $page): RedirectResponse
    {
        Gate::authorize('delete', $page);
        // Soft-deleted; its address is freed for a new page.
        $page->forceFill(['slug' => Slugs::retired($page->slug, $page->id, Slugs::PAGE_MAX)])->save();
        $page->delete();

        return $this->toIndex($mosque, 'manage.page_deleted');
    }

    /** @return array<string, mixed> */
    private function summary(MosquePage $page): array
    {
        $at = $page->getAttribute('published_at');

        return [
            'id' => $page->id,
            'title' => $page->title,
            'slug' => $page->slug,
            'sort' => (int) $page->sort,
            'show_in_menu' => (bool) $page->show_in_menu,
            'published' => $at instanceof CarbonInterface && ! $at->isFuture(),
        ];
    }

    private function fill(MosquePage $page, SavePageRequest $request, Mosque $mosque): void
    {
        $data = $request->validated();
        $published = $request->boolean('published');
        $current = $page->getAttribute('published_at');
        $page->fill([
            'title' => $data['title'],
            'body' => $data['body'],
            'sort' => (int) ($data['sort'] ?? 0),
            'show_in_menu' => $request->boolean('show_in_menu'),
            'published_at' => $published ? ($current instanceof CarbonInterface && ! $current->isFuture() ? $current : now()) : null,
        ]);
        $chosen = filled($data['slug'] ?? null);
        $automatic = fn () => Slugs::unique('mosque_pages', $mosque->id,
            Slugs::base($data['title'], 'page', Slugs::PAGE_MAX), $page->exists ? $page->id : null, Slugs::PAGE_MAX);
        $page->slug = $chosen ? $data['slug'] : ($page->slug ?: $automatic());

        // Two pages given the same address at the same moment: the later one takes the
        // next free automatic address, or goes back to the form (never a server error).
        try {
            DB::transaction(fn () => $page->save());
        } catch (UniqueConstraintViolationException) {
            if ($chosen) {
                throw ValidationException::withMessages(['slug' => ui('manage.slug_taken')]);
            }
            $page->slug = $automatic();
            $page->save();
        }
    }

    private function toIndex(Mosque $mosque, string $message): RedirectResponse
    {
        Inertia::flash('toast', ['type' => 'success', 'message' => ui($message)]);

        return to_route('manage.pages.index', $mosque);
    }
}
