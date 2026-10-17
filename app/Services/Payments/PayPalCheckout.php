<?php

namespace App\Services\Payments;

use App\Models\Campaign;
use App\Models\Donation;
use App\Models\MosquePayoutMethod;
use App\Services\Fundraising\CampaignPresenter;
use App\Services\Fundraising\DonationLedger;
use App\Services\Fundraising\PaymentMethods;
use Illuminate\Support\Facades\Log;

/**
 * A PayPal donation from order to capture. The amount and the payee come
 * from the server (the pending donation and the mosque's verified account),
 * never from the browser, and the captured order is checked against them —
 * status, amount, currency, payee, reference — before it counts.
 */
class PayPalCheckout
{
    public function __construct(
        private readonly PayPalClient $client,
        private readonly DonationLedger $ledger,
    ) {}

    /** Creates the order for a pending donation; returns PayPal's order id. */
    public function start(Donation $donation, Campaign $campaign, MosquePayoutMethod $paypal): string
    {
        $payee = PaymentMethods::payee($paypal);
        // PayPal's page names the mosque as the one being paid, never the platform.
        $mosque = CampaignPresenter::mosqueOf($campaign)?->name;
        $orderId = $this->client->createOrder($donation->reference, (int) $donation->amount, $donation->currency, $campaign->title, $payee, $mosque);

        // The payee we asked PayPal to pay is kept: the capture must match it.
        $donation->forceFill([
            'paypal_order_id' => $orderId,
            'provider_payload' => ['payee' => $payee, 'order_status' => 'CREATED'],
        ])->save();

        return $orderId;
    }

    /**
     * Captures the approved order (again: PayPal answers a repeat with the
     * same capture) and records the outcome.
     *
     * @return string "completed", "pending" (PayPal still processing) or "failed"
     */
    public function capture(Donation $donation): string
    {
        if ($donation->status === 'completed') {
            return 'completed';
        }
        if ($donation->status === 'refunded' || ! $donation->paypal_order_id) {
            return 'failed';
        }

        try {
            $order = $this->client->captureOrder($donation->paypal_order_id, $donation->reference);
        } catch (PayPalException $e) {
            if (! $e->alreadyCaptured()) {
                throw $e;
            }
            $order = $this->client->getOrder($donation->paypal_order_id);
        }

        if (data_get($order, 'purchase_units.0.payee') === null) {
            $order = $this->client->getOrder($donation->paypal_order_id);
        }

        return $this->settle($donation, $order);
    }

    /**
     * Checks an order as PayPal reports it against the donation, then counts
     * it, refuses it or waits for PayPal.
     *
     * @param  array<string, mixed>  $order
     */
    public function settle(Donation $donation, array $order): string
    {
        $parsed = PayPalOrder::fromArray($order);
        $payload = [
            ...(array) $donation->provider_payload,
            'order_status' => $parsed->status,
            'capture_status' => $parsed->captureStatus,
        ];

        $problem = $this->mismatch($donation, $parsed);
        if ($problem !== null) {
            Log::warning('PayPal order does not match its donation', [
                'donation_id' => $donation->id, 'order_id' => $parsed->id, 'mismatch' => $problem,
            ]);
            $this->ledger->cancel($donation, 'failed');

            return $donation->status === 'completed' ? 'completed' : 'failed';
        }

        if ($parsed->isCompleted()) {
            $this->ledger->complete($donation, [
                'paypal_capture_id' => $parsed->captureId,
                'confirmed_at' => now(),
                'provider_payload' => $payload,
            ]);

            return 'completed';
        }

        if (in_array($parsed->captureStatus, ['DECLINED', 'FAILED'], true)) {
            $this->ledger->cancel($donation, 'failed');

            return 'failed';
        }

        // PENDING (e.g. under review at PayPal): the webhook will settle it.
        $donation->forceFill(['paypal_capture_id' => $parsed->captureId, 'provider_payload' => $payload])->save();

        return 'pending';
    }

    /** What differs between the order and the donation, or null when everything matches. */
    private function mismatch(Donation $donation, PayPalOrder $order): ?string
    {
        if ($order->id !== $donation->paypal_order_id) {
            return 'order';
        }
        if ($order->customId !== null && $order->customId !== $donation->reference) {
            return 'reference';
        }
        if ($order->amount !== (int) $donation->amount) {
            return 'amount';
        }
        if ($order->currency !== $donation->currency) {
            return 'currency';
        }

        $payee = (array) data_get($donation->provider_payload, 'payee', []);
        if (isset($payee['merchant_id'])) {
            return $order->payeeMerchantId === $payee['merchant_id'] ? null : 'payee';
        }
        if (isset($payee['email_address'])) {
            return $order->payeeEmail !== null && strcasecmp($order->payeeEmail, (string) $payee['email_address']) === 0 ? null : 'payee';
        }

        return 'payee';
    }
}
