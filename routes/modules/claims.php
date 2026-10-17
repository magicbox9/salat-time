<?php

use App\Http\Controllers\Claims\ClaimDocumentController;
use App\Http\Controllers\Claims\MosqueClaimController;
use App\Http\Controllers\Claims\MyClaimsController;
use App\Http\Controllers\Claims\WithdrawClaimController;
use Illuminate\Support\Facades\Route;

// Requests to manage a mosque's page (reviewed by a platform admin).
Route::middleware(['auth', 'verified'])->group(function () {
    Route::get('mosques/{mosque}/claim', [MosqueClaimController::class, 'create'])
        ->where('mosque', '[a-z0-9-]+')
        ->name('claims.create');

    Route::post('mosques/{mosque}/claim', [MosqueClaimController::class, 'store'])
        ->where('mosque', '[a-z0-9-]+')
        ->middleware('throttle:claims-submit')
        ->name('claims.store');

    Route::get('me/claims', MyClaimsController::class)->name('claims.mine');

    Route::delete('me/claims/{claim}', WithdrawClaimController::class)
        ->whereNumber('claim')
        ->middleware('throttle:30,1,claims-withdraw:')
        ->name('claims.withdraw');

    // Streams a claim's private supporting document (admins and the claimant only).
    Route::get('claims/{claim}/document', ClaimDocumentController::class)
        ->whereNumber('claim')
        ->middleware('throttle:claims-document')
        ->name('claims.document');
});
