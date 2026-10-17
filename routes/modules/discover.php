<?php

/*
 * Discover + home: "/" (the visitor's own mosque — the hub — or the globe
 * before one is chosen), "/explore" (always the globe), place search, nearby
 * mosques, the map's mosque dots, each user's saved mosques ("my mosques"),
 * "Make it my mosque" for everyone and the hub's display preferences.
 *
 * The JSON paths below (mosques/near.json …) have a single segment after
 * "mosques/", so they must be registered before any `mosques/{mosque}` page
 * route; slugs never contain a dot, so a `where('mosque', '[a-z0-9-]+')`
 * constraint on such a route keeps them apart for good.
 */

use App\Http\Controllers\Discover\FavoriteMosqueController;
use App\Http\Controllers\Discover\GeocodeController;
use App\Http\Controllers\Discover\HomeController;
use App\Http\Controllers\Discover\MosqueSearchController;
use App\Http\Controllers\Discover\MosquesInBoundsController;
use App\Http\Controllers\Discover\MyMosquesController;
use App\Http\Controllers\Discover\NearbyMosquesController;
use App\Http\Controllers\Discover\PrimaryMosqueController;
use App\Http\Controllers\Hub\ChosenMosqueController;
use App\Http\Controllers\Hub\HomePreferencesController;
use Illuminate\Support\Facades\Route;

Route::get('/', [HomeController::class, 'home'])->name('home');
Route::get('explore', [HomeController::class, 'explore'])->name('explore');

// "Make it my mosque" (guests: an encrypted cookie; users: their primary saved mosque).
Route::middleware('throttle:30,1,my-mosque:')->group(function () {
    Route::post('my-mosque', [ChosenMosqueController::class, 'store'])->name('my-mosque.store');
    Route::delete('my-mosque', [ChosenMosqueController::class, 'destroy'])->name('my-mosque.destroy');
});

Route::patch('me/preferences/home', HomePreferencesController::class)
    ->middleware(['auth', 'throttle:60,1,home-preferences:'])
    ->name('me.preferences.home');

// Address lookups reach outside services: 30 per minute per visitor.
Route::get('geocode.json', GeocodeController::class)
    ->middleware('throttle:30,1,geocode:')
    ->name('geocode');

Route::middleware('throttle:120,1,discover:')->group(function () {
    Route::get('mosques/near.json', NearbyMosquesController::class)->name('mosques.near');
    Route::get('mosques/in-bounds.json', MosquesInBoundsController::class)->name('mosques.in-bounds');
    Route::get('mosques/search.json', MosqueSearchController::class)->name('mosques.search');
});

// Slugs only: a {mosque} segment never captures a ".json" path.
Route::middleware(['auth', 'throttle:60,1,favorites:'])->where(['mosque' => '[a-z0-9-]+'])->group(function () {
    Route::post('mosques/{mosque}/favorite', [FavoriteMosqueController::class, 'store'])->name('mosques.favorite.store');
    Route::delete('mosques/{mosque}/favorite', [FavoriteMosqueController::class, 'destroy'])->name('mosques.favorite.destroy');
    Route::post('mosques/{mosque}/primary', [PrimaryMosqueController::class, 'store'])->name('mosques.primary.store');
    Route::delete('mosques/{mosque}/primary', [PrimaryMosqueController::class, 'destroy'])->name('mosques.primary.destroy');
});

Route::get('me/mosques', MyMosquesController::class)
    ->middleware(['auth', 'verified'])
    ->name('me.mosques');
