<?php

use App\Http\Controllers\Api\V1\MeController;
use App\Http\Controllers\Api\V1\PrayerLogController;
use Illuminate\Support\Facades\Route;
use Laravel\Sanctum\Http\Middleware\CheckAbilities;

/*
| API v1 for the iOS / Android companion apps. Authenticate with a personal
| access token created in Settings → Companion app:
|   Authorization: Bearer <token>   Accept: application/json
| Optional X-Timezone: <IANA zone> sets "today" when no own mosque is chosen.
| Timestamps (prayed_at, metrics.started_at / ended_at) are ISO 8601 with an
| offset (…T13:05:00+01:00 or …T12:05:00Z) and come back in UTC.
| Success: {"data": …, "meta"?: …}; errors: {"message": …, "code"?: …, "errors"?: …}.
*/
Route::prefix('v1')
    ->name('api.v1.')
    ->middleware(['auth:sanctum', 'throttle:120,1,api-v1'])
    ->group(function () {
        Route::middleware(CheckAbilities::class.':prayers:read')->group(function () {
            Route::get('me', [MeController::class, 'show'])->name('me');
            Route::get('me/mosque/times', [MeController::class, 'times'])->name('me.mosque.times');
            Route::get('me/summary', [MeController::class, 'summary'])->name('me.summary');
            Route::get('prayer-logs', [PrayerLogController::class, 'index'])->name('prayer-logs.index');
        });

        Route::post('prayer-logs', [PrayerLogController::class, 'store'])
            ->middleware([CheckAbilities::class.':prayers:write', 'throttle:30,1,api-v1-write'])
            ->name('prayer-logs.store');
    });
