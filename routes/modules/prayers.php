<?php

use App\Http\Controllers\Prayers\PrayerLogController;
use App\Http\Controllers\Prayers\PrayerTrackerController;
use App\Http\Controllers\Settings\ApiTokenController;
use Illuminate\Auth\Middleware\RequirePassword;
use Illuminate\Support\Facades\Route;

// The personal prayer tracker (hasanat) and the companion-app tokens.
Route::middleware(['auth', 'verified'])->group(function () {
    Route::get('prayers', PrayerTrackerController::class)->name('prayers.index');

    Route::post('prayers/logs', [PrayerLogController::class, 'store'])
        ->middleware('throttle:30,1,prayer-logs')
        ->name('prayers.logs.store');
    Route::delete('prayers/logs/{log}', [PrayerLogController::class, 'destroy'])
        ->whereNumber('log')
        ->middleware('throttle:30,1,prayer-logs')
        ->name('prayers.logs.destroy');

    Route::get('settings/api-tokens', [ApiTokenController::class, 'index'])
        ->middleware(RequirePassword::class)
        ->name('api-tokens.index');
    Route::post('settings/api-tokens', [ApiTokenController::class, 'store'])
        ->middleware([RequirePassword::class, 'throttle:6,1,api-tokens'])
        ->name('api-tokens.store');
    Route::delete('settings/api-tokens/{token}', [ApiTokenController::class, 'destroy'])
        ->whereNumber('token')
        ->middleware('throttle:20,1,api-tokens-revoke')
        ->name('api-tokens.destroy');
});
