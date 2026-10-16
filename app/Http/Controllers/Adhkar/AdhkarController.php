<?php

namespace App\Http\Controllers\Adhkar;

use App\Http\Controllers\Controller;
use App\Services\Content\AdhkarLibrary;
use Inertia\Inertia;
use Inertia\Response;

/** Hisn al-Muslim adhkar: the category grid and one category's cards. */
class AdhkarController extends Controller
{
    public function index(AdhkarLibrary $library): Response
    {
        return Inertia::render('adhkar/index', [
            'categories' => $library->categories(),
        ]);
    }

    public function show(string $category, AdhkarLibrary $library): Response
    {
        $items = $library->items($category);
        abort_if($items === null, 404);

        $current = null;
        $related = [];
        foreach ($library->categories() as $entry) {
            if ($entry['key'] === $category) {
                $current = $entry;
            } else {
                $related[] = $entry;
            }
        }

        return Inertia::render('adhkar/show', [
            'category' => $current,
            'items' => $items,
            'related' => $related,
        ]);
    }
}
