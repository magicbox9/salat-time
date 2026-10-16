<?php

use App\Http\Controllers\Admin\ClaimController;
use App\Http\Controllers\Admin\ClaimReviewController;
use App\Http\Controllers\Admin\MosqueController;
use App\Http\Controllers\Admin\MosqueManagerController;
use App\Http\Controllers\Admin\MosqueVerificationController;
use App\Http\Controllers\Admin\OverviewController;
use App\Http\Controllers\Admin\UserAdminController;
use App\Http\Controllers\Admin\UserController;
use Illuminate\Support\Facades\Route;

// Platform administration. The 'admin' gate reads users.is_admin from the database.
Route::middleware(['auth', 'verified', 'can:admin'])
    ->prefix('admin')
    ->name('admin.')
    ->group(function () {
        Route::get('/', OverviewController::class)->name('index');

        Route::get('claims', [ClaimController::class, 'index'])->name('claims.index');
        Route::get('claims/{claim}', [ClaimController::class, 'show'])->whereNumber('claim')->name('claims.show');

        Route::get('mosques', [MosqueController::class, 'index'])->name('mosques.index');
        Route::get('mosques/{mosque}', [MosqueController::class, 'edit'])
            ->where('mosque', '[a-z0-9-]+')
            ->name('mosques.edit');

        Route::get('users', UserController::class)->name('users.index');

        Route::middleware('throttle:admin-write')->group(function () {
            Route::post('claims/{claim}/approve', [ClaimReviewController::class, 'approve'])
                ->whereNumber('claim')
                ->name('claims.approve');
            Route::post('claims/{claim}/reject', [ClaimReviewController::class, 'reject'])
                ->whereNumber('claim')
                ->name('claims.reject');

            Route::patch('mosques/{mosque}', [MosqueController::class, 'update'])
                ->where('mosque', '[a-z0-9-]+')
                ->name('mosques.update');
            Route::post('mosques/{mosque}/verify', [MosqueVerificationController::class, 'store'])
                ->where('mosque', '[a-z0-9-]+')
                ->name('mosques.verify');
            Route::delete('mosques/{mosque}/verify', [MosqueVerificationController::class, 'destroy'])
                ->where('mosque', '[a-z0-9-]+')
                ->name('mosques.unverify');
            Route::delete('mosques/{mosque}/managers/{user}', [MosqueManagerController::class, 'destroy'])
                ->where('mosque', '[a-z0-9-]+')
                ->whereNumber('user')
                ->name('mosques.managers.destroy');

            Route::post('users/{user}/admin', [UserAdminController::class, 'store'])
                ->whereNumber('user')
                ->name('users.admin.grant');
            Route::delete('users/{user}/admin', [UserAdminController::class, 'destroy'])
                ->whereNumber('user')
                ->name('users.admin.revoke');
        });
    });
