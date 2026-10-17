<?php

namespace App\Http\Controllers\MosquePage;

use App\Http\Controllers\Controller;
use App\Http\Controllers\MosquePage\Support\BlogPosts;
use App\Http\Controllers\MosquePage\Support\Slugs;
use App\Models\Mosque;
use App\Models\MosquePost;
use Illuminate\Http\RedirectResponse;

/**
 * Posts used to live on the mosque's page as "#post-{id}" anchors. Their old
 * links (and links to posts without an address yet) land on the article.
 */
class LegacyPostController extends Controller
{
    public function __invoke(Mosque $mosque, MosquePost $post): RedirectResponse
    {
        abort_unless(BlogPosts::isPublic($post), 404);
        Slugs::ensureForPosts([$post]);

        return redirect()->route('mosques.blog.show', [$mosque, $post->slug], 301);
    }
}
