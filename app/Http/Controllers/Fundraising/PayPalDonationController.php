<?php

namespace App\Http\Controllers\Fundraising;

use App\Http\Controllers\Controller;
use App\Http\Controllers\Fundraising\Requests\DonateRequest;
use App\Models\Campaign;
use App\Models\Donation;
use App\Services\Fundraising\CampaignPresenter;
use App\Services\Fundraising\DonationIntake;
use App\Services\Fundraising\DonationLedger;
use App\Services\Fundraising\PaymentMethods;
use App\Services\Payments\PayPalCheckout;
use App\Services\Payments\PayPalException;
use Illuminate\Http\JsonResponse;
use Illuminate\Support\Facades\Log;

/**
 * PayPal donations, called by the PayPal buttons on the campaign page:
 * create the order (server amount, the mosque's verified account as payee),
 * then capture it once the donor approved it.
 */
class PayPalDonationController extends Controller
{
    public function store(DonateRequest $request, Campaign $campaign, PaymentMethods $methods, DonationIntake $intake, PayPalCheckout $checkout): JsonResponse
    {
        $campaign->loadMissing('mosque.payoutMethods');
        $mosque = CampaignPresenter::mosqueOf($campaign);
        $paypal = $mosque ? $methods->verifiedPayouts($mosque)['paypal'] : null;
        if (! $methods->available($campaign)['paypal'] || ! $paypal) {
            return response()->json(['message' => ui('fundraising.method_unavailable')], 422);
        }

        /** @var array{amount: int, donor_name: string, donor_email: string, anonymous?: bool, message?: string|null} $data */
        $data = $request->validated();
        $donation = $intake->create($campaign, 'paypal', $data, $request->user());

        try {
            $orderId = $checkout->start($donation, $campaign, $paypal);
        } catch (PayPalException $e) {
            Log::warning('PayPal order could not be created', ['donation_id' => $donation->id, 'error' => $e->getMessage()]);
            $donation->forceFill(['status' => 'failed'])->save();

            return response()->json(['message' => ui('fundraising.paypal_unavailable')], 502);
        }

        return response()->json(['order_id' => $orderId, 'reference' => $donation->reference]);
    }

    public function capture(Campaign $campaign, string $order, PayPalCheckout $checkout): JsonResponse
    {
        $donation = $this->donation($campaign, $order);

        try {
            $result = $checkout->capture($donation);
        } catch (PayPalException $e) {
            Log::warning('PayPal capture failed', ['donation_id' => $donation->id, 'error' => $e->getMessage()]);

            return response()->json(['status' => 'error', 'message' => ui('fundraising.paypal_capture_failed')], 502);
        }

        if ($result === 'failed') {
            return response()->json(['status' => 'failed', 'message' => ui('fundraising.paypal_declined')], 422);
        }

        return response()->json([
            'status' => $result,
            'redirect' => DonationReceiptController::link($donation->reference),
        ]);
    }

    /** The donor closed PayPal without paying: the pending donation is dropped. */
    public function cancel(Campaign $campaign, string $order, DonationLedger $ledger): JsonResponse
    {
        $donation = $this->donation($campaign, $order);
        if ($donation->status === 'pending' && ! $donation->paypal_capture_id) {
            $ledger->cancel($donation);
        }

        return response()->json(['status' => $donation->status]);
    }

    private function donation(Campaign $campaign, string $order): Donation
    {
        return Donation::query()
            ->where('campaign_id', $campaign->id)
            ->where('method', 'paypal')
            ->where('paypal_order_id', $order)
            ->firstOrFail();
    }
}
