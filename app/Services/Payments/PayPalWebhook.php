<?php

namespace App\Services\Payments;

use App\Models\Donation;
use App\Services\Fundraising\DonationLedger;
use App\Services\Fundraising\DonationReference;
use Illuminate\Support\Facades\Log;

/**
 * PayPal's notifications about captures, handled idempotently: an event seen
 * twice changes nothing, and a completed capture is re-read from PayPal and
 * checked like a capture made from the page.
 */
class PayPalWebhook
{
    public const EVENTS = [
        'PAYMENT.CAPTURE.COMPLETED',
        'PAYMENT.CAPTURE.DENIED',
        'PAYMENT.CAPTURE.REFUNDED',
        'PAYMENT.CAPTURE.REVERSED',
    ];

    public function __construct(
        private readonly PayPalClient $client,
        private readonly PayPalCheckout $checkout,
        private readonly DonationLedger $ledger,
    ) {}

    /** @param  array<string, mixed>  $event */
    public function handle(array $event): void
    {
        $type = $event['event_type'] ?? null;
        $eventId = is_string($event['id'] ?? null) ? $event['id'] : null;
        if (! in_array($type, self::EVENTS, true)) {
            return;
        }

        $resource = (array) ($event['resource'] ?? []);
        $donation = $this->donationFor($type, $resource);
        if (! $donation || $donation->method !== 'paypal') {
            return;
        }
        if ($eventId && in_array($eventId, (array) data_get($donation->provider_payload, 'events', []), true)) {
            return;
        }

        match ($type) {
            'PAYMENT.CAPTURE.COMPLETED' => $this->completed($donation),
            'PAYMENT.CAPTURE.DENIED' => $this->ledger->reverse($donation, 'failed'),
            default => $this->ledger->reverse($donation, 'refunded'),
        };

        $this->remember($donation, $eventId);
    }

    private function completed(Donation $donation): void
    {
        if ($donation->status === 'completed' || ! $donation->paypal_order_id) {
            return;
        }

        try {
            $this->checkout->settle($donation, $this->client->getOrder($donation->paypal_order_id));
        } catch (PayPalException $e) {
            Log::warning('PayPal webhook: order could not be read', ['donation_id' => $donation->id, 'error' => $e->getMessage()]);

            throw $e;   // a 5xx makes PayPal deliver the event again later
        }
    }

    /** @param  array<string, mixed>  $resource */
    private function donationFor(string $type, array $resource): ?Donation
    {
        $orderId = data_get($resource, 'supplementary_data.related_ids.order_id');
        if (is_string($orderId) && $orderId !== '') {
            $found = Donation::query()->where('paypal_order_id', $orderId)->first();
            if ($found) {
                return $found;
            }
        }

        // A refund or a reversal carries a refund resource that names its
        // capture in its "up" link; the other events carry the capture itself.
        $captureIds = in_array($type, ['PAYMENT.CAPTURE.REFUNDED', 'PAYMENT.CAPTURE.REVERSED'], true)
            ? [$this->capturedFrom($resource), $resource['id'] ?? null]
            : [$resource['id'] ?? null];
        foreach ($captureIds as $captureId) {
            if (is_string($captureId) && $captureId !== '') {
                $found = Donation::query()->where('paypal_capture_id', $captureId)->first();
                if ($found) {
                    return $found;
                }
            }
        }

        $reference = $resource['custom_id'] ?? null;

        return is_string($reference) && preg_match(DonationReference::PATTERN, $reference)
            ? Donation::query()->where('reference', $reference)->first()
            : null;
    }

    /**
     * A refund (or a reversal) names its capture in its "up" link.
     *
     * @param  array<string, mixed>  $resource
     */
    private function capturedFrom(array $resource): ?string
    {
        foreach ((array) ($resource['links'] ?? []) as $link) {
            if (($link['rel'] ?? null) === 'up' && preg_match('#/v2/payments/captures/([A-Z0-9]+)$#', (string) ($link['href'] ?? ''), $m)) {
                return $m[1];
            }
        }

        return null;
    }

    private function remember(Donation $donation, ?string $eventId): void
    {
        if (! $eventId) {
            return;
        }
        $fresh = $donation->fresh() ?? $donation;
        /** @var array<string, mixed> $payload */
        $payload = (array) $fresh->provider_payload;
        $seen = isset($payload['events']) && is_array($payload['events']) ? $payload['events'] : [];
        $payload['events'] = array_slice([...$seen, $eventId], -20);
        $fresh->forceFill(['provider_payload' => $payload])->save();
    }
}
