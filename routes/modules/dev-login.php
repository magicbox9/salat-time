<?php

use App\Http\Controllers\Dev\DevLoginController;
use Illuminate\Support\Facades\Route;

// Development only (config/devlogin.php): one-click sign-in as a test account.
if (config('devlogin.enabled') && app()->isLocal()) {
    Route::post('dev-login/{account}', DevLoginController::class)
        ->middleware('guest')
        ->whereIn('account', array_keys(config('devlogin.accounts')))
        ->name('dev-login');
}
