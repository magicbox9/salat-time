<?php

namespace App\Http\Controllers\Admin\Fundraising;

use App\Http\Controllers\Admin\AdminController;
use App\Models\Campaign;
use App\Models\Donation;
use App\Models\MosquePayoutMethod;
use App\Services\Payments\PayPalClient;
use Inertia\Response;

/** /admin/fundraising — campaigns to review, accounts to verify, and the platform's figures. */
class FundraisingOverviewController extends AdminController
{
    public function __invoke(PayPalClient $paypal): Response
    {
        $totals = Donation::query()
            ->selectRaw("COALESCE(SUM(amount) FILTER (WHERE status = 'completed'), 0) AS raised")
            ->selectRaw("COUNT(*) FILTER (WHERE status = 'completed') AS donations")
            ->selectRaw("COALESCE(SUM(amount) FILTER (WHERE status = 'pending' AND method = 'bank'), 0) AS pledged")
            ->first();

        return $this->page('admin/fundraising/index', [
            'stats' => [
                'campaigns_pending' => Campaign::query()->where('status', 'pending')->count(),
                'campaigns_active' => Campaign::query()->where('status', 'active')->count(),
                'payouts_to_verify' => MosquePayoutMethod::query()->whereNull('verified_at')->count(),
                'payouts_verified' => MosquePayoutMethod::query()->whereNotNull('verified_at')->count(),
                'raised' => (int) ($totals->raised ?? 0),
                'pledged' => (int) ($totals->pledged ?? 0),
                'donations' => (int) ($totals->donations ?? 0),
                'currency' => config('fundraising.currency'),
            ],
            'pendingCampaigns' => CampaignReviewController::rows(
                Campaign::query()->where('status', 'pending')->oldest('updated_at')->limit(5)
            ),
            'payoutsToVerify' => PayoutReviewController::rows(
                MosquePayoutMethod::query()->whereNull('verified_at')->oldest('updated_at')->limit(5)
            ),
            'paypal' => [
                'configured' => $paypal->isConfigured(),
                'webhook' => $paypal->webhookConfigured(),
                'mode' => $paypal->mode(),
            ],
        ]);
    }
}
