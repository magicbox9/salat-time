<?php

use App\Http\Controllers\LocaleController;
use App\Http\Controllers\Mosques\MosqueTimesController;
use Illuminate\Support\Facades\Route;

Route::inertia('/', 'home')->name('home');

Route::post('locale', LocaleController::class)->name('locale.update');

Route::get('mosques/{mosque}/times.json', MosqueTimesController::class)
    ->middleware('throttle:120,1')
    ->name('mosques.times');

Route::middleware(['auth', 'verified'])->group(function () {
    Route::inertia('dashboard', 'dashboard')->name('dashboard');
});

// Each feature keeps its own route file in routes/modules/.
foreach (glob(__DIR__.'/modules/*.php') ?: [] as $file) {
    require $file;
}

require __DIR__.'/settings.php';
