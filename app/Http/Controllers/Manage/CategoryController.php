<?php

namespace App\Http\Controllers\Manage;

use App\Http\Controllers\Controller;
use App\Http\Controllers\Manage\Support\DefaultCategories;
use App\Http\Controllers\MosquePage\Support\Slugs;
use App\Http\Requests\Manage\ReorderCategoriesRequest;
use App\Http\Requests\Manage\SaveCategoryRequest;
use App\Models\Mosque;
use App\Models\MosquePost;
use App\Models\MosquePostCategory;
use App\Support\MosquePresenter;
use Illuminate\Database\Eloquent\Collection;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Gate;
use Illuminate\Validation\ValidationException;
use Inertia\Inertia;
use Inertia\Response;

/** The categories of a mosque's blog: list, create, rename, reorder, delete. */
class CategoryController extends Controller
{
    public const MAX = 30;

    public function index(Request $request, Mosque $mosque, DefaultCategories $defaults): Response
    {
        $defaults->ensure($mosque, $request->user());
        /** @var Collection<int, MosquePostCategory> $categories */
        $categories = $mosque->postCategories()->withCount('posts')->get();

        return Inertia::render('manage/categories', [
            'mosque' => MosquePresenter::summary($mosque),
            'categories' => $categories
                ->map(fn (MosquePostCategory $c) => [
                    'id' => $c->id,
                    'name' => $c->name,
                    'slug' => $c->slug,
                    'description' => $c->description,
                    'posts_count' => (int) $c->getAttribute('posts_count'),
                ])
                ->values()
                ->all(),
            'max' => self::MAX,
        ]);
    }

    public function store(SaveCategoryRequest $request, Mosque $mosque): RedirectResponse
    {
        if ($mosque->postCategories()->count() >= self::MAX) {
            throw ValidationException::withMessages(['name' => ui('manage.categories_full', ['max' => self::MAX])]);
        }

        $data = $request->validated();
        MosquePostCategory::query()->create([
            'mosque_id' => $mosque->id,
            'name' => trim($data['name']),
            'description' => filled($data['description'] ?? null) ? trim($data['description']) : null,
            'slug' => Slugs::unique('mosque_post_categories', $mosque->id,
                Slugs::base($data['name'], 'category', 80), null, 80),
            'sort' => (int) $mosque->postCategories()->max('sort') + 1,
        ]);

        return $this->back('manage.category_created');
    }

    /** Renaming keeps the address, so links to the category keep working. */
    public function update(SaveCategoryRequest $request, Mosque $mosque, MosquePostCategory $postCategory): RedirectResponse
    {
        Gate::authorize('update', $postCategory);
        $data = $request->validated();
        $postCategory->update([
            'name' => trim($data['name']),
            'description' => filled($data['description'] ?? null) ? trim($data['description']) : null,
        ]);

        return $this->back('manage.category_updated');
    }

    public function reorder(ReorderCategoriesRequest $request, Mosque $mosque): RedirectResponse
    {
        DB::transaction(function () use ($request, $mosque): void {
            foreach (array_values($request->validated('ids')) as $position => $id) {
                MosquePostCategory::query()->where('mosque_id', $mosque->id)->whereKey((int) $id)->update(['sort' => $position]);
            }
        });

        return $this->back('manage.categories_reordered');
    }

    /** The category goes; its posts stay, without a category. */
    public function destroy(Mosque $mosque, MosquePostCategory $postCategory): RedirectResponse
    {
        Gate::authorize('delete', $postCategory);
        DB::transaction(function () use ($postCategory): void {
            MosquePost::withTrashed()->where('category_id', $postCategory->id)->toBase()->update(['category_id' => null]);
            $postCategory->delete();
        });

        return $this->back('manage.category_deleted');
    }

    private function back(string $message): RedirectResponse
    {
        return Inertia::flash('toast', ['type' => 'success', 'message' => ui($message)])->back();
    }
}
