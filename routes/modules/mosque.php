<?php

use App\Http\Controllers\Manage\CategoryController;
use App\Http\Controllers\Manage\CommentModerationController;
use App\Http\Controllers\Manage\ManageIndexController;
use App\Http\Controllers\Manage\ManageOverviewController;
use App\Http\Controllers\Manage\MarkdownPreviewController;
use App\Http\Controllers\Manage\MosqueSettingsController;
use App\Http\Controllers\Manage\PageController;
use App\Http\Controllers\Manage\PostController;
use App\Http\Controllers\MosquePage\BlogController;
use App\Http\Controllers\MosquePage\CommentController;
use App\Http\Controllers\MosquePage\LegacyPostController;
use App\Http\Controllers\MosquePage\PostFeedController;
use App\Http\Controllers\MosquePage\ShowMosqueController;
use App\Http\Controllers\MosquePage\SitePageController;
use App\Http\Controllers\MosquePage\Support\Slugs;
use Illuminate\Support\Facades\Route;

// Mosque page slugs only: never captures /mosques/near.json and friends.
$mosqueSlug = '[a-z0-9-]+';

// Addresses of posts and pages ("cours-de-tajwid"): never a .json endpoint.
$contentSlug = Slugs::PATTERN;

// Record ids that fit PostgreSQL's bigint: a longer number is a 404, not a database error.
$mosqueRecordId = '[1-9][0-9]{0,17}';

// The mosque's site: home, blog, articles and pages.
Route::get('mosques/{mosque}', ShowMosqueController::class)
    ->where('mosque', $mosqueSlug)
    ->name('mosques.show');

Route::get('mosques/{mosque}/blog', [BlogController::class, 'index'])
    ->where('mosque', $mosqueSlug)
    ->middleware('throttle:120,1,mosque-blog')
    ->name('mosques.blog');

Route::get('mosques/{mosque}/blog/{postSlug}', [BlogController::class, 'show'])
    ->where(['mosque' => $mosqueSlug, 'postSlug' => $contentSlug])
    ->name('mosques.blog.show');

Route::get('mosques/{mosque}/pages/{pageSlug}', SitePageController::class)
    ->where(['mosque' => $mosqueSlug, 'pageSlug' => $contentSlug])
    ->name('mosques.pages.show');

Route::get('mosques/{mosque}/posts.json', PostFeedController::class)
    ->where('mosque', $mosqueSlug)
    ->middleware('throttle:60,1,mosque-feed')
    ->name('mosques.posts');

Route::scopeBindings()->group(function () use ($mosqueSlug, $mosqueRecordId) {
    // Old "#post-{id}" links and posts without an address yet: on to the article.
    Route::get('mosques/{mosque}/posts/{post}', LegacyPostController::class)
        ->where(['mosque' => $mosqueSlug, 'post' => $mosqueRecordId])
        ->name('mosques.posts.legacy');

    Route::get('mosques/{mosque}/posts/{post}/comments', [CommentController::class, 'index'])
        ->where('mosque', $mosqueSlug)
        ->where('post', $mosqueRecordId)
        ->middleware('throttle:60,1,mosque-comments-read')
        ->name('mosques.comments.index');

    Route::post('mosques/{mosque}/posts/{post}/comments', [CommentController::class, 'store'])
        ->where('mosque', $mosqueSlug)
        ->where('post', $mosqueRecordId)
        ->middleware(['auth', 'verified', 'throttle:5,1,mosque-comment'])
        ->name('mosques.comments.store');
});

Route::middleware(['auth', 'throttle:30,1,mosque-comment-admin'])->group(function () use ($mosqueRecordId) {
    Route::delete('comments/{comment}', [CommentController::class, 'destroy'])
        ->where('comment', $mosqueRecordId)
        ->name('comments.destroy');
    Route::patch('comments/{comment}/hide', [CommentModerationController::class, 'hide'])
        ->where('comment', $mosqueRecordId)
        ->middleware('verified')
        ->name('comments.hide');
    Route::patch('comments/{comment}/unhide', [CommentModerationController::class, 'unhide'])
        ->where('comment', $mosqueRecordId)
        ->middleware('verified')
        ->name('comments.unhide');
});

// Management of a mosque's site (MosquePolicy@manage: an admin or one of its managers).
// Display, campaigns and payouts have their own route files (modules "display" and "fundraising").
Route::middleware(['auth', 'verified'])
    ->prefix('manage')
    ->name('manage.')
    ->group(function () use ($mosqueSlug, $mosqueRecordId) {
        Route::get('/', ManageIndexController::class)->name('index');

        Route::middleware('can:manage,mosque')
            ->where([
                'mosque' => $mosqueSlug,
                'post' => $mosqueRecordId,
                'page' => $mosqueRecordId,
                'postCategory' => $mosqueRecordId,
            ])
            ->group(function () {
                Route::get('{mosque}', ManageOverviewController::class)->name('overview');
                Route::get('{mosque}/details', [MosqueSettingsController::class, 'edit'])->name('edit');

                Route::get('{mosque}/posts', [PostController::class, 'index'])->name('posts.index');
                Route::get('{mosque}/posts/create', [PostController::class, 'create'])->name('posts.create');
                Route::get('{mosque}/posts/{post}/edit', [PostController::class, 'edit'])
                    ->scopeBindings()
                    ->name('posts.edit');

                Route::get('{mosque}/categories', [CategoryController::class, 'index'])->name('categories.index');

                Route::get('{mosque}/pages', [PageController::class, 'index'])->name('pages.index');
                Route::get('{mosque}/pages/create', [PageController::class, 'create'])->name('pages.create');
                Route::get('{mosque}/pages/{page}/edit', [PageController::class, 'edit'])
                    ->scopeBindings()
                    ->name('pages.edit');

                Route::get('{mosque}/comments', [CommentModerationController::class, 'index'])->name('comments');

                // The editor's live preview: one request per pause in typing.
                Route::post('{mosque}/markdown-preview', MarkdownPreviewController::class)
                    ->middleware('throttle:60,1,manage-markdown-preview')
                    ->name('markdown-preview');

                Route::middleware('throttle:30,1,manage-write')->scopeBindings()->group(function () {
                    Route::put('{mosque}', [MosqueSettingsController::class, 'update'])->name('update');

                    Route::post('{mosque}/posts', [PostController::class, 'store'])->name('posts.store');
                    Route::put('{mosque}/posts/{post}', [PostController::class, 'update'])->name('posts.update');
                    Route::delete('{mosque}/posts/{post}', [PostController::class, 'destroy'])->name('posts.destroy');

                    Route::post('{mosque}/categories', [CategoryController::class, 'store'])->name('categories.store');
                    Route::put('{mosque}/categories/order', [CategoryController::class, 'reorder'])->name('categories.reorder');
                    Route::put('{mosque}/categories/{postCategory}', [CategoryController::class, 'update'])
                        ->name('categories.update');
                    Route::delete('{mosque}/categories/{postCategory}', [CategoryController::class, 'destroy'])
                        ->name('categories.destroy');

                    Route::post('{mosque}/pages', [PageController::class, 'store'])->name('pages.store');
                    Route::put('{mosque}/pages/{page}', [PageController::class, 'update'])->name('pages.update');
                    Route::delete('{mosque}/pages/{page}', [PageController::class, 'destroy'])->name('pages.destroy');
                });
            });
    });
