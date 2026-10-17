<?php

/*
 * The full-screen prayer display — module "display".
 *
 *  - /mosques/{slug}/display       a mosque's screen (TV in the prayer hall)
 *  - /mosques/{slug}/display.json  its data for a week (public, cached a minute)
 *  - /mosques/{slug}/display/stamp.json  changes when that data changes (asked every minute)
 *  - /display                      the visitor's own mosque, personal settings
 *  - /display/settings             those personal settings
 *  - /manage/{slug}/display        the mosque's screen settings (MosquePolicy@manage)
 *  - /adhan/catalog.json           the adhan recordings a screen can play
 */

use App\Http\Controllers\Display\AdhanCatalogController;
use App\Http\Controllers\Display\DisplayDataController;
use App\Http\Controllers\Display\DisplayMediaController;
use App\Http\Controllers\Display\DisplayMessageController;
use App\Http\Controllers\Display\DisplayScreenController;
use App\Http\Controllers\Display\DisplayStampController;
use App\Http\Controllers\Display\MosqueDisplaySettingsController;
use App\Http\Controllers\Display\PersonalDisplaySettingsController;
use Illuminate\Support\Facades\Route;

// Slugs never contain a dot, so these never capture a ".json" path.
$mosqueSlug = '[a-z0-9-]+';
$recordId = '[1-9][0-9]{0,17}';

Route::get('adhan/catalog.json', AdhanCatalogController::class)
    ->middleware('throttle:60,1,adhan-catalog')
    ->name('adhan.catalog');

Route::get('mosques/{mosque}/display.json', DisplayDataController::class)
    ->where('mosque', $mosqueSlug)
    ->middleware('throttle:120,1,display-data')
    ->name('mosques.display.data');

Route::get('mosques/{mosque}/display/stamp.json', DisplayStampController::class)
    ->where('mosque', $mosqueSlug)
    ->middleware('throttle:240,1,display-stamp')
    ->name('mosques.display.stamp');

Route::get('mosques/{mosque}/display', [DisplayScreenController::class, 'mosque'])
    ->where('mosque', $mosqueSlug)
    ->name('mosques.display');

Route::get('display', [DisplayScreenController::class, 'personal'])->name('display.personal');

Route::get('display/settings', [PersonalDisplaySettingsController::class, 'edit'])->name('display.settings');
Route::put('display/settings', [PersonalDisplaySettingsController::class, 'update'])
    ->middleware(['auth', 'throttle:30,1,display-personal'])
    ->name('display.settings.update');

Route::middleware(['auth', 'verified', 'can:manage,mosque'])
    ->prefix('manage/{mosque}/display')
    ->where(['mosque' => $mosqueSlug])
    ->name('manage.display.')
    ->group(function () use ($recordId) {
        Route::get('/', [MosqueDisplaySettingsController::class, 'edit'])->name('edit');

        Route::middleware('throttle:30,1,display-manage')->group(function () use ($recordId) {
            Route::put('/', [MosqueDisplaySettingsController::class, 'update'])->name('update');

            Route::post('messages', [DisplayMessageController::class, 'store'])->name('messages.store');
            Route::put('messages/order', [DisplayMessageController::class, 'reorder'])->name('messages.reorder');
            Route::put('messages/{message}', [DisplayMessageController::class, 'update'])
                ->where('message', $recordId)
                ->name('messages.update');
            Route::delete('messages/{message}', [DisplayMessageController::class, 'destroy'])
                ->where('message', $recordId)
                ->name('messages.destroy');
        });

        Route::middleware('throttle:10,1,display-upload')->group(function () {
            Route::post('background', [DisplayMediaController::class, 'storeBackground'])->name('background.store');
            Route::delete('background', [DisplayMediaController::class, 'destroyBackground'])->name('background.destroy');
            Route::post('adhan', [DisplayMediaController::class, 'storeAdhan'])->name('adhan.store');
            Route::delete('adhan', [DisplayMediaController::class, 'destroyAdhan'])->name('adhan.destroy');
        });
    });
