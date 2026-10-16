<?php

namespace App\Http\Controllers\MosquePage;

use App\Http\Controllers\Controller;
use App\Http\Controllers\MosquePage\Support\PostFeed;
use App\Models\Mosque;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

/** The next page of a mosque's feed ("Load more"). */
class PostFeedController extends Controller
{
    public function __invoke(Request $request, Mosque $mosque, PostFeed $feed): JsonResponse
    {
        $data = $request->validate([
            'cursor' => ['nullable', 'string', 'max:500'],
        ]);
        $canManage = $request->user()?->can('manage', $mosque) ?? false;

        return response()->json($feed->page($mosque, $data['cursor'] ?? null, $canManage));
    }
}
