<?php

use App\Http\Controllers\Manage\CommentModerationController;
use App\Http\Controllers\Manage\ManageIndexController;
use App\Http\Controllers\Manage\MosqueSettingsController;
use App\Http\Controllers\Manage\PostController;
use App\Http\Controllers\MosquePage\CommentController;
use App\Http\Controllers\MosquePage\PostFeedController;
use App\Http\Controllers\MosquePage\ShowMosqueController;
use Illuminate\Support\Facades\Route;

// Mosque page slugs only: never captures /mosques/near.json and friends.
$mosqueSlug = '[a-z0-9-]+';

// Record ids that fit PostgreSQL's bigint: a longer number is a 404, not a database error.
$mosqueRecordId = '[1-9][0-9]{0,17}';

// The public page of a mosque, its feed and the comments under its posts.
Route::get('mosques/{mosque}', ShowMosqueController::class)
    ->where('mosque', $mosqueSlug)
    ->name('mosques.show');

Route::get('mosques/{mosque}/posts.json', PostFeedController::class)
    ->where('mosque', $mosqueSlug)
    ->middleware('throttle:60,1,mosque-feed')
    ->name('mosques.posts');

Route::scopeBindings()->group(function () use ($mosqueSlug, $mosqueRecordId) {
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

// Management of a mosque's page (MosquePolicy@manage: an admin or one of its managers).
Route::middleware(['auth', 'verified'])
    ->prefix('manage')
    ->name('manage.')
    ->group(function () use ($mosqueSlug, $mosqueRecordId) {
        Route::get('/', ManageIndexController::class)->name('index');

        Route::middleware('can:manage,mosque')->group(function () use ($mosqueSlug, $mosqueRecordId) {
            Route::get('{mosque}', [MosqueSettingsController::class, 'edit'])
                ->where('mosque', $mosqueSlug)
                ->name('edit');
            Route::get('{mosque}/posts', [PostController::class, 'index'])
                ->where('mosque', $mosqueSlug)
                ->name('posts.index');
            Route::get('{mosque}/posts/create', [PostController::class, 'create'])
                ->where('mosque', $mosqueSlug)
                ->name('posts.create');
            Route::get('{mosque}/posts/{post}/edit', [PostController::class, 'edit'])
                ->where('mosque', $mosqueSlug)
                ->where('post', $mosqueRecordId)
                ->scopeBindings()
                ->name('posts.edit');
            Route::get('{mosque}/comments', [CommentModerationController::class, 'index'])
                ->where('mosque', $mosqueSlug)
                ->name('comments');

            Route::middleware('throttle:30,1,manage-write')->group(function () use ($mosqueSlug, $mosqueRecordId) {
                Route::put('{mosque}', [MosqueSettingsController::class, 'update'])
                    ->where('mosque', $mosqueSlug)
                    ->name('update');
                Route::post('{mosque}/posts', [PostController::class, 'store'])
                    ->where('mosque', $mosqueSlug)
                    ->name('posts.store');
                Route::put('{mosque}/posts/{post}', [PostController::class, 'update'])
                    ->where('mosque', $mosqueSlug)
                    ->where('post', $mosqueRecordId)
                    ->scopeBindings()
                    ->name('posts.update');
                Route::delete('{mosque}/posts/{post}', [PostController::class, 'destroy'])
                    ->where('mosque', $mosqueSlug)
                    ->where('post', $mosqueRecordId)
                    ->scopeBindings()
                    ->name('posts.destroy');
            });
        });
    });
