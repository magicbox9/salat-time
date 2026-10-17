<?php

namespace App\Http\Controllers\Manage;

use App\Http\Controllers\Controller;
use App\Http\Requests\Manage\MarkdownPreviewRequest;
use App\Models\Mosque;
use App\Support\Markdown;
use Illuminate\Http\JsonResponse;

/**
 * The editor's live preview: the server renders the Markdown exactly as the
 * public page will (raw HTML stripped, unsafe links refused).
 */
class MarkdownPreviewController extends Controller
{
    public function __invoke(MarkdownPreviewRequest $request, Mosque $mosque): JsonResponse
    {
        return response()->json(['html' => Markdown::toHtml($request->validated('body'))]);
    }
}
