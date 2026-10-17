<?php

namespace App\Http\Controllers\Fundraising;

use App\Http\Controllers\Controller;
use App\Services\Payments\PayPalClient;
use App\Services\Payments\PayPalException;
use App\Services\Payments\PayPalWebhook;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Log;

/**
 * POST /webhooks/paypal — PayPal's notifications about captures. Nothing is
 * trusted before PayPal's own verify-webhook-signature API confirms the
 * delivery; a forged or unsigned request is refused with 400.
 */
class PayPalWebhookController extends Controller
{
    public function __invoke(Request $request, PayPalClient $client, PayPalWebhook $webhook): JsonResponse
    {
        $raw = $request->getContent();
        if ($raw === '' || strlen($raw) > 256 * 1024) {
            return response()->json(['message' => 'Invalid payload.'], 400);
        }

        $headers = [];
        foreach (['PAYPAL-AUTH-ALGO', 'PAYPAL-CERT-URL', 'PAYPAL-TRANSMISSION-ID', 'PAYPAL-TRANSMISSION-SIG', 'PAYPAL-TRANSMISSION-TIME'] as $name) {
            $headers[$name] = $request->header($name);
        }

        if (! $client->verifyWebhook($headers, $raw)) {
            Log::notice('PayPal webhook refused: signature not verified', ['transmission_id' => $headers['PAYPAL-TRANSMISSION-ID']]);

            return response()->json(['message' => 'Signature not verified.'], 400);
        }

        $event = json_decode($raw, true);

        try {
            $webhook->handle(is_array($event) ? $event : []);
        } catch (PayPalException) {
            return response()->json(['message' => 'Try again later.'], 503);
        }

        return response()->json(['received' => true]);
    }
}
