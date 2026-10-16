<?php

namespace App\Http\Controllers\Discover;

use App\Http\Controllers\Controller;
use App\Models\Mosque;
use App\Support\MosquePresenter;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

/** GET /mosques/search.json?q=… → mosques whose name or city looks like the text (fuzzy). */
class MosqueSearchController extends Controller
{
    public const LIMIT = 15;

    public function __invoke(Request $request): JsonResponse
    {
        $data = $request->validate([
            'q' => ['required', 'string', 'min:2', 'max:100'],
        ]);

        // Text with no letters or digits left once accents and symbols are
        // dropped (emoji, punctuation) would match every mosque: answer nothing.
        if (preg_match_all('/[a-z0-9]/', Mosque::searchKey($data['q'])) < 2) {
            return response()->json(['mosques' => []]);
        }

        $mosques = Mosque::search($data['q'])
            ->withCount('calendars')
            ->limit(self::LIMIT)
            ->get();

        return response()->json([
            'mosques' => $mosques->map(fn (Mosque $m) => MosquePresenter::summary($m))->values(),
        ]);
    }
}
