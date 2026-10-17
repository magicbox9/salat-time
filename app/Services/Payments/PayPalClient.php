<?php

namespace App\Services\Payments;

use Illuminate\Http\Client\ConnectionException;
use Illuminate\Http\Client\PendingRequest;
use Illuminate\Http\Client\Response;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Str;

/**
 * PayPal REST (Orders v2 and webhook verification) for donations paid
 * straight to a mosque: the order names the mosque's own verified PayPal
 * account as the payee, so the money never passes through the platform.
 *
 * Secrets stay here: they are sent only to PayPal and never logged; errors
 * carry PayPal's status and error name only.
 */
class PayPalClient
{
    /** @return bool A client id and secret are set: the PayPal method can be offered. */
    public function isConfigured(): bool
    {
        return filled(config('fundraising.paypal.client_id')) && filled(config('fundraising.paypal.client_secret'));
    }

    public function webhookConfigured(): bool
    {
        return $this->isConfigured() && filled(config('fundraising.paypal.webhook_id'));
    }

    /** "sandbox" or "live". */
    public function mode(): string
    {
        return config('fundraising.paypal.mode') === 'live' ? 'live' : 'sandbox';
    }

    /** The public client id the JavaScript SDK is loaded with (never the secret). */
    public function clientId(): ?string
    {
        return $this->isConfigured() ? (string) config('fundraising.paypal.client_id') : null;
    }

    /**
     * Creates an order paid to the mosque (intent CAPTURE). PayPal-Request-Id
     * makes a retried call return the same order.
     *
     * @param  array{email_address?: string, merchant_id?: string}  $payee
     * @param  string|null  $brand  The name PayPal shows as the one being paid: the mosque's.
     * @return string The PayPal order id.
     */
    public function createOrder(string $reference, int $amount, string $currency, string $description, array $payee, ?string $brand = null): string
    {
        $brand = Str::squish((string) $brand) !== '' ? Str::squish((string) $brand) : (string) config('fundraising.paypal.brand_name');

        $unit = [
            'reference_id' => $reference,
            'custom_id' => $reference,
            'invoice_id' => $reference,
            'description' => Str::limit(Str::squish($description), 120, ''),
            'amount' => ['currency_code' => $currency, 'value' => PayPalOrder::value($amount)],
            'payee' => $payee,
        ];
        $descriptor = Str::squish((string) config('fundraising.paypal.soft_descriptor'));
        if ($descriptor !== '') {
            $unit['soft_descriptor'] = Str::limit($descriptor, 22, '');
        }

        $body = [
            'intent' => 'CAPTURE',
            'purchase_units' => [$unit],
            'application_context' => [
                'brand_name' => Str::limit($brand, 120, ''),
                'shipping_preference' => 'NO_SHIPPING',
                'user_action' => 'PAY_NOW',
            ],
        ];

        $response = $this->send(fn (PendingRequest $http) => $http
            ->withHeaders(['PayPal-Request-Id' => 'order-'.$reference, 'Prefer' => 'return=minimal'])
            ->post('/v2/checkout/orders', $body));

        $id = $response->json('id');
        if (! is_string($id) || ! preg_match('/^[A-Z0-9]{8,40}$/', $id)) {
            throw new PayPalException('PayPal returned no order id', $response->status());
        }

        return $id;
    }

    /**
     * Captures an approved order and returns it in full.
     *
     * @return array<string, mixed>
     */
    public function captureOrder(string $orderId, string $requestId): array
    {
        return (array) $this->send(fn (PendingRequest $http) => $http
            ->withHeaders(['PayPal-Request-Id' => 'capture-'.$requestId, 'Prefer' => 'return=representation'])
            ->withBody('{}', 'application/json')
            ->post('/v2/checkout/orders/'.rawurlencode($orderId).'/capture'))->json();
    }

    /** @return array<string, mixed> */
    public function getOrder(string $orderId): array
    {
        return (array) $this->send(fn (PendingRequest $http) => $http
            ->get('/v2/checkout/orders/'.rawurlencode($orderId)))->json();
    }

    /**
     * Asks PayPal whether a webhook delivery is genuine. The event is passed
     * byte for byte as received (re-encoding it would break the signature).
     *
     * @param  array<string, string|null>  $headers  The PAYPAL-* transmission headers.
     */
    public function verifyWebhook(array $headers, string $rawBody): bool
    {
        if (! $this->webhookConfigured() || ! is_array(json_decode($rawBody, true))) {
            return false;
        }

        $fields = [
            'auth_algo' => $headers['PAYPAL-AUTH-ALGO'] ?? null,
            'cert_url' => $headers['PAYPAL-CERT-URL'] ?? null,
            'transmission_id' => $headers['PAYPAL-TRANSMISSION-ID'] ?? null,
            'transmission_sig' => $headers['PAYPAL-TRANSMISSION-SIG'] ?? null,
            'transmission_time' => $headers['PAYPAL-TRANSMISSION-TIME'] ?? null,
        ];
        foreach ($fields as $value) {
            if (! is_string($value) || $value === '' || strlen($value) > 2048) {
                return false;
            }
        }

        // The event is appended as the last member, byte for byte: no value
        // sent by the caller (the headers) can ever be swapped for it.
        $json = (string) json_encode([...$fields, 'webhook_id' => (string) config('fundraising.paypal.webhook_id')], JSON_UNESCAPED_SLASHES);
        $body = substr($json, 0, -1).',"webhook_event":'.trim($rawBody).'}';

        try {
            $response = $this->send(fn (PendingRequest $http) => $http
                ->withBody($body, 'application/json')
                ->post('/v1/notifications/verify-webhook-signature'));
        } catch (PayPalException) {
            return false;
        }

        return $response->json('verification_status') === 'SUCCESS';
    }

    /**
     * Sends an authenticated request; an expired token is renewed once.
     *
     * @param  callable(PendingRequest): Response  $call
     */
    private function send(callable $call): Response
    {
        if (! $this->isConfigured()) {
            throw new PayPalException('PayPal is not configured');
        }

        try {
            $response = $call($this->http()->withToken($this->token()));
            if ($response->status() === 401) {
                Cache::forget($this->tokenKey());
                $response = $call($this->http()->withToken($this->token()));
            }
        } catch (ConnectionException) {
            throw new PayPalException('PayPal unreachable');
        }

        if (! $response->successful()) {
            $name = $response->json('name');
            $issue = $response->json('details.0.issue');

            throw new PayPalException(
                'PayPal answered '.$response->status().(is_string($name) ? ' '.$name : ''),
                $response->status(),
                is_string($issue) ? $issue : (is_string($name) ? $name : null),
            );
        }

        return $response;
    }

    /** An OAuth access token, cached until shortly before it expires. */
    private function token(): string
    {
        $cached = Cache::get($this->tokenKey());
        if (is_string($cached) && $cached !== '') {
            return $cached;
        }

        try {
            $response = $this->http()
                ->withBasicAuth((string) config('fundraising.paypal.client_id'), (string) config('fundraising.paypal.client_secret'))
                ->asForm()
                ->post('/v1/oauth2/token', ['grant_type' => 'client_credentials']);
        } catch (ConnectionException) {
            throw new PayPalException('PayPal unreachable');
        }

        $token = $response->json('access_token');
        if (! $response->successful() || ! is_string($token) || $token === '') {
            throw new PayPalException('PayPal refused the credentials', $response->status());
        }

        $ttl = max(60, (int) $response->json('expires_in', 3600) - 300);
        Cache::put($this->tokenKey(), $token, $ttl);

        return $token;
    }

    private function http(): PendingRequest
    {
        $timeout = (int) config('fundraising.paypal.timeout', 15);

        return Http::baseUrl((string) config('fundraising.paypal.api.'.$this->mode()))
            ->acceptJson()
            ->timeout($timeout)
            ->connectTimeout(min(5, $timeout))
            ->retry(2, 300, fn ($exception) => $exception instanceof ConnectionException, throw: false);
    }

    /** Keyed by mode and client id (never the secret). */
    private function tokenKey(): string
    {
        return 'paypal-token:'.$this->mode().':'.hash('sha256', (string) config('fundraising.paypal.client_id'));
    }
}
