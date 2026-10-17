<?php

/*
 * Fundraising: campaigns of mosques, donations paid straight to the mosque
 * (PayPal with the mosque's own account as payee, or a bank transfer to its
 * IBAN), the managers' tools and the admins' reviews.
 *
 * Slugs are constrained so no {campaign} or {mosque} parameter ever captures
 * a .json path, and PayPal order ids so they never capture anything else.
 */

use App\Http\Controllers\Admin\Fundraising\CampaignReviewController;
use App\Http\Controllers\Admin\Fundraising\FundraisingOverviewController;
use App\Http\Controllers\Admin\Fundraising\PayoutReviewController;
use App\Http\Controllers\Fundraising\BankDonationController;
use App\Http\Controllers\Fundraising\CampaignIndexController;
use App\Http\Controllers\Fundraising\CampaignProgressController;
use App\Http\Controllers\Fundraising\CampaignShowController;
use App\Http\Controllers\Fundraising\DonationReceiptController;
use App\Http\Controllers\Fundraising\Manage\CampaignController;
use App\Http\Controllers\Fundraising\Manage\CampaignLifecycleController;
use App\Http\Controllers\Fundraising\Manage\CampaignUpdateController;
use App\Http\Controllers\Fundraising\Manage\DonationController;
use App\Http\Controllers\Fundraising\Manage\PayoutMethodController;
use App\Http\Controllers\Fundraising\MosqueCampaignsController;
use App\Http\Controllers\Fundraising\MyDonationsController;
use App\Http\Controllers\Fundraising\PayPalDonationController;
use App\Http\Controllers\Fundraising\PayPalWebhookController;
use Illuminate\Foundation\Http\Middleware\PreventRequestForgery;
use Illuminate\Support\Facades\Route;

$slug = '[a-z0-9-]+';
$orderId = '[A-Z0-9]{8,40}';
$recordId = '[1-9][0-9]{0,17}';

// ── Public pages and live figures ───────────────────────────────────────────
Route::get('campaigns', CampaignIndexController::class)->name('campaigns.index');

Route::get('campaigns/{campaign}/progress.json', CampaignProgressController::class)
    ->where('campaign', $slug)
    ->middleware('throttle:120,1,campaign-progress:')
    ->name('campaigns.progress');

Route::get('campaigns/{campaign}', CampaignShowController::class)
    ->where('campaign', $slug)
    ->name('campaigns.show');

Route::get('mosques/{mosque}/campaigns.json', [MosqueCampaignsController::class, 'json'])
    ->where('mosque', $slug)
    ->middleware('throttle:120,1,mosque-campaigns:')
    ->name('mosques.campaigns.json');

Route::get('mosques/{mosque}/campaigns', [MosqueCampaignsController::class, 'page'])
    ->where('mosque', $slug)
    ->name('mosques.campaigns');

// The donor's own page for a donation (signed link: no guessing references).
Route::get('donations/{reference}', DonationReceiptController::class)
    ->where('reference', 'ST-[A-Z0-9]{4}-[A-Z0-9]{4}')
    ->middleware(['signed:relative', 'throttle:60,1,donation-receipt:'])
    ->name('donations.show');

// ── Giving ──────────────────────────────────────────────────────────────────
// Per visitor: 10 a minute, 60 a day (a donation form is not a script's playground).
Route::middleware(['throttle:10,1,donate:', 'throttle:60,1440,donate-day:'])->group(function () use ($slug) {
    Route::post('campaigns/{campaign}/donations/paypal', [PayPalDonationController::class, 'store'])
        ->where('campaign', $slug)
        ->name('campaigns.donations.paypal');
    Route::post('campaigns/{campaign}/donations/bank', [BankDonationController::class, 'store'])
        ->where('campaign', $slug)
        ->name('campaigns.donations.bank');
});

Route::middleware('throttle:30,1,donate-capture:')->group(function () use ($slug, $orderId) {
    Route::post('campaigns/{campaign}/donations/paypal/{order}/capture', [PayPalDonationController::class, 'capture'])
        ->where(['campaign' => $slug, 'order' => $orderId])
        ->name('campaigns.donations.paypal.capture');
    Route::post('campaigns/{campaign}/donations/paypal/{order}/cancel', [PayPalDonationController::class, 'cancel'])
        ->where(['campaign' => $slug, 'order' => $orderId])
        ->name('campaigns.donations.paypal.cancel');
});

// PayPal's notifications: no session token, the signature is checked with PayPal instead.
Route::post('webhooks/paypal', PayPalWebhookController::class)
    ->withoutMiddleware([PreventRequestForgery::class])
    ->middleware('throttle:300,1,paypal-webhook:')
    ->name('webhooks.paypal');

Route::get('me/donations', MyDonationsController::class)
    ->middleware(['auth'])
    ->name('me.donations');

// ── The mosque's managers (MosquePolicy@manage) ─────────────────────────────
Route::middleware(['auth', 'verified', 'can:manage,mosque'])
    ->prefix('manage/{mosque}')
    ->where(['mosque' => $slug])
    ->name('manage.')
    ->group(function () use ($slug, $recordId) {
        Route::get('payouts', [PayoutMethodController::class, 'index'])->name('payouts.index');
        Route::get('campaigns', [CampaignController::class, 'index'])->name('campaigns.index');
        Route::get('campaigns/create', [CampaignController::class, 'create'])->name('campaigns.create');
        Route::get('donations', [DonationController::class, 'index'])->name('donations.index');
        Route::get('donations/export.csv', [DonationController::class, 'export'])
            ->middleware('throttle:10,1,donations-export:')
            ->name('donations.export');

        Route::scopeBindings()->group(function () use ($slug) {
            Route::get('campaigns/{campaign}', [CampaignController::class, 'show'])
                ->where('campaign', $slug)
                ->name('campaigns.show');
            Route::get('campaigns/{campaign}/edit', [CampaignController::class, 'edit'])
                ->where('campaign', $slug)
                ->name('campaigns.edit');
        });

        Route::middleware('throttle:30,1,fundraising-write:')->group(function () use ($slug, $recordId) {
            Route::post('payouts', [PayoutMethodController::class, 'store'])->name('payouts.store');
            Route::put('payouts/{type}', [PayoutMethodController::class, 'update'])
                ->whereIn('type', ['paypal', 'bank'])
                ->name('payouts.update');
            Route::delete('payouts/{type}', [PayoutMethodController::class, 'destroy'])
                ->whereIn('type', ['paypal', 'bank'])
                ->name('payouts.destroy');

            Route::post('campaigns', [CampaignController::class, 'store'])->name('campaigns.store');

            Route::scopeBindings()->group(function () use ($slug, $recordId) {
                Route::put('campaigns/{campaign}', [CampaignController::class, 'update'])
                    ->where('campaign', $slug)
                    ->name('campaigns.update');
                Route::delete('campaigns/{campaign}', [CampaignController::class, 'destroy'])
                    ->where('campaign', $slug)
                    ->name('campaigns.destroy');
                Route::post('campaigns/{campaign}/submit', [CampaignLifecycleController::class, 'submit'])
                    ->where('campaign', $slug)
                    ->name('campaigns.submit');
                Route::post('campaigns/{campaign}/close', [CampaignLifecycleController::class, 'close'])
                    ->where('campaign', $slug)
                    ->name('campaigns.close');
                Route::post('campaigns/{campaign}/updates', [CampaignUpdateController::class, 'store'])
                    ->where('campaign', $slug)
                    ->name('campaigns.updates.store');
                Route::delete('campaigns/{campaign}/updates/{update}', [CampaignUpdateController::class, 'destroy'])
                    ->where(['campaign' => $slug, 'update' => $recordId])
                    ->name('campaigns.updates.destroy');
            });

            Route::post('donations/{donation}/confirm', [DonationController::class, 'confirm'])
                ->where('donation', $recordId)
                ->name('donations.confirm');
            Route::post('donations/{donation}/cancel', [DonationController::class, 'cancel'])
                ->where('donation', $recordId)
                ->name('donations.cancel');
        });
    });

// ── Platform admins ─────────────────────────────────────────────────────────
Route::middleware(['auth', 'verified', 'can:admin'])
    ->prefix('admin/fundraising')
    ->name('admin.fundraising.')
    ->group(function () use ($slug, $recordId) {
        Route::get('/', FundraisingOverviewController::class)->name('index');
        Route::get('payouts', [PayoutReviewController::class, 'index'])->name('payouts.index');
        Route::get('campaigns', [CampaignReviewController::class, 'index'])->name('campaigns.index');
        Route::get('campaigns/{campaign}', [CampaignReviewController::class, 'show'])
            ->where('campaign', $slug)
            ->name('campaigns.show');

        Route::post('payouts/{payout}/reveal', [PayoutReviewController::class, 'reveal'])
            ->where('payout', $recordId)
            ->middleware('throttle:20,1,payout-reveal:')
            ->name('payouts.reveal');

        Route::middleware('throttle:admin-write')->group(function () use ($slug, $recordId) {
            Route::post('payouts/{payout}/verify', [PayoutReviewController::class, 'verify'])
                ->where('payout', $recordId)
                ->name('payouts.verify');
            Route::delete('payouts/{payout}/verify', [PayoutReviewController::class, 'unverify'])
                ->where('payout', $recordId)
                ->name('payouts.unverify');
            Route::post('campaigns/{campaign}/approve', [CampaignReviewController::class, 'approve'])
                ->where('campaign', $slug)
                ->name('campaigns.approve');
            Route::post('campaigns/{campaign}/reject', [CampaignReviewController::class, 'reject'])
                ->where('campaign', $slug)
                ->name('campaigns.reject');
            Route::post('campaigns/{campaign}/close', [CampaignReviewController::class, 'close'])
                ->where('campaign', $slug)
                ->name('campaigns.close');
        });
    });
