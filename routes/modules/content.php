<?php

use App\Http\Controllers\Adhkar\AdhkarController;
use App\Http\Controllers\Quran\QuranBookmarkController;
use App\Http\Controllers\Quran\QuranController;
use App\Services\Content\AdhkarLibrary;
use Illuminate\Support\Facades\Route;

// Adhkar (Hisn al-Muslim) and the Qur'an reader — module "content".

Route::get('adhkar', [AdhkarController::class, 'index'])->name('adhkar.index');
Route::get('adhkar/{category}', [AdhkarController::class, 'show'])
    ->whereIn('category', AdhkarLibrary::CATEGORIES)
    ->name('adhkar.show');

Route::get('quran', [QuranController::class, 'index'])->name('quran.index');
// One canonical URL per surah: "/quran/7", never "/quran/007".
Route::get('quran/{surah}', [QuranController::class, 'show'])
    ->where('surah', '[1-9][0-9]{0,2}')
    ->name('quran.show');

// The named prefix keeps this limit apart from other per-user limits
// (an unprefixed "throttle:60,1" shares one counter with "throttle:6,1"
// on password and verification routes).
Route::middleware(['auth', 'throttle:60,1,quran-bookmarks'])->group(function () {
    Route::post('quran/bookmarks', [QuranBookmarkController::class, 'store'])->name('quran.bookmarks.store');
    Route::delete('quran/bookmarks/{bookmark}', [QuranBookmarkController::class, 'destroy'])
        ->whereNumber('bookmark')
        ->name('quran.bookmarks.destroy');
});
