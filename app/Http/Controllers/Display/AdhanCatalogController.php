<?php

namespace App\Http\Controllers\Display;

use App\Http\Controllers\Controller;
use App\Models\Mosque;
use App\Services\Display\AdhanCatalog;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

/**
 * GET /adhan/catalog.json → { adhans: [{ id, name, url }] }: the recordings
 * present on the server (possibly none) and, with ?mosque={slug}, that
 * mosque's own adhan.
 */
class AdhanCatalogController extends Controller
{
    public function __invoke(Request $request, AdhanCatalog $catalog): JsonResponse
    {
        $data = $request->validate([
            'mosque' => ['nullable', 'string', 'max:255', 'regex:/^[a-z0-9-]+$/'],
        ]);
        $mosque = isset($data['mosque'])
            ? Mosque::query()->with('displaySetting')->where('slug', $data['mosque'])->first()
            : null;

        return response()
            ->json(['adhans' => $catalog->list($mosque)])
            ->header('Cache-Control', 'private, max-age=300');
    }
}
