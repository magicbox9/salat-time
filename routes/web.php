<?php

use App\Http\Controllers\Auth\SignInReturnController;
use App\Http\Controllers\DashboardController;
use App\Http\Controllers\LocaleController;
use App\Http\Controllers\Mosques\MosqueTimesController;
use Illuminate\Support\Facades\Route;

Route::post('locale', LocaleController::class)->name('locale.update');

// "Sign in to do this": back to the page the guest was on afterwards.
Route::get('sign-in', SignInReturnController::class)->name('sign-in');

Route::get('mosques/{mosque}/times.json', MosqueTimesController::class)
    ->middleware('throttle:120,1')
    ->name('mosques.times');

Route::middleware(['auth', 'verified'])->group(function () {
    Route::get('dashboard', DashboardController::class)->name('dashboard');
});

// Each feature keeps its own route file in routes/modules/.
foreach (glob(__DIR__.'/modules/*.php') ?: [] as $file) {
    require $file;
}

require __DIR__.'/settings.php';
