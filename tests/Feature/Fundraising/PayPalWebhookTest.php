<?php

namespace Tests\Feature\Fundraising;

use App\Models\Donation;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\Client\Request;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Notification;
use Illuminate\Testing\TestResponse;
use Tests\TestCase;

class PayPalWebhookTest extends TestCase
{
    use FundraisingFixtures, RefreshDatabase;

    private const ORDER = '7XG12345AB678901C';

    private string $verification = 'SUCCESS';

    private Donation $donation;

    protected function setUp(): void
    {
        parent::setUp();
        $this->setUpFundraising();
        Notification::fake();

        $this->donation = Donation::factory()->create([
            'campaign_id' => $this->campaign->id,
            'mosque_id' => $this->mosque->id,
            'method' => 'paypal',
            'amount' => 4000,
            'reference' => 'ST-ABCD-EFGH',
        ]);
        $this->donation->forceFill([
            'paypal_order_id' => self::ORDER,
            'provider_payload' => ['payee' => ['email_address' => 'tresorier@mosquee-test.fr']],
        ])->save();

        Http::fake(function (Request $request) {
            $url = $request->url();
            if (str_ends_with($url, '/v1/oauth2/token')) {
                return Http::response(['access_token' => 'A21-test-token', 'expires_in' => 32400]);
            }
            if (str_ends_with($url, '/v1/notifications/verify-webhook-signature')) {
                return Http::response(['verification_status' => $this->verification]);
            }
            if (str_ends_with($url, '/v2/checkout/orders/'.self::ORDER)) {
                return Http::response($this->paypalOrder(self::ORDER, 'ST-ABCD-EFGH', '40.00'));
            }

            return Http::response([], 404);
        });
    }

    /** @return array<string, mixed> */
    private function event(string $type, string $id = 'WH-EVENT-1'): array
    {
        return [
            'id' => $id,
            'event_type' => $type,
            'resource' => [
                'id' => 'CAPTURE7XG12345',
                'status' => 'COMPLETED',
                'amount' => ['currency_code' => 'EUR', 'value' => '40.00'],
                'custom_id' => 'ST-ABCD-EFGH',
                'supplementary_data' => ['related_ids' => ['order_id' => self::ORDER]],
            ],
        ];
    }

    private function deliver(array $event, string $algo = 'SHA256withRSA'): TestResponse
    {
        return $this->call('POST', '/webhooks/paypal', [], [], [], [
            'CONTENT_TYPE' => 'application/json',
            'HTTP_ACCEPT' => 'application/json',
            'HTTP_PAYPAL_AUTH_ALGO' => $algo,
            'HTTP_PAYPAL_CERT_URL' => 'https://api.sandbox.paypal.com/v1/notifications/certs/CERT-360caa42',
            'HTTP_PAYPAL_TRANSMISSION_ID' => '69cd13f0-d67a-11e5-baa3-778b53f4ae55',
            'HTTP_PAYPAL_TRANSMISSION_SIG' => 'lmI95Jx3Y9nhR5SJWlHVIWpg4AgFk7n9bCHSRxbrd8A9zrhdu2rMyFrmz+Zjh3s3boXB07VXCXUZy/UFzUlnGJn0wDugt7FlSvdKeIJenLRemUxYCPVoEZzg9VFNqOa48gMkvF+XTpxBeUx/kWy6B5cp7GkT2+pOowfRK7OaynuxUoKW3JcMWw272VKjLTtTAShncla7tGF+55rxyt2KNZIIqxNMJ48RDZheGU5w1npu9dZHnPgTXB9iomeVRoD8O/jhRpnKsGrDschyNdkeh81BJJMH4Ctc6lnCCquoP/GzCzz33MMsNdid7vL/NIWaCsekQpW26FpWPi/tfj8nLA==',
            'HTTP_PAYPAL_TRANSMISSION_TIME' => '2026-10-17T18:41:28Z',
        ], json_encode($event));
    }

    public function test_an_unverified_signature_is_refused_and_changes_nothing(): void
    {
        $this->verification = 'FAILURE';

        $this->deliver($this->event('PAYMENT.CAPTURE.COMPLETED'))->assertStatus(400);
        $this->assertSame('pending', $this->donation->fresh()->status);
        Http::assertNotSent(fn (Request $r) => str_contains($r->url(), '/v2/checkout/orders/'));
    }

    public function test_a_request_without_paypal_headers_is_refused_without_calling_paypal(): void
    {
        $this->postJson('/webhooks/paypal', $this->event('PAYMENT.CAPTURE.COMPLETED'))->assertStatus(400);
        Http::assertNothingSent();
        $this->assertSame('pending', $this->donation->fresh()->status);
    }

    public function test_the_signature_check_sends_the_event_exactly_as_received(): void
    {
        $event = $this->event('PAYMENT.CAPTURE.COMPLETED');
        $this->deliver($event)->assertOk();

        Http::assertSent(fn (Request $r) => str_ends_with($r->url(), '/v1/notifications/verify-webhook-signature')
            && $r->data()['webhook_id'] === 'WH-TEST-123'
            && $r->data()['webhook_event'] === $event
            && $r->data()['transmission_id'] === '69cd13f0-d67a-11e5-baa3-778b53f4ae55');
    }

    public function test_a_completed_capture_completes_the_donation_once(): void
    {
        $this->deliver($this->event('PAYMENT.CAPTURE.COMPLETED'))->assertOk();
        $this->deliver($this->event('PAYMENT.CAPTURE.COMPLETED'))->assertOk();
        $this->deliver($this->event('PAYMENT.CAPTURE.COMPLETED', 'WH-EVENT-2'))->assertOk();

        $this->assertSame('completed', $this->donation->fresh()->status);
        $campaign = $this->campaign->fresh();
        $this->assertSame(4000, $campaign->raised_amount);
        $this->assertSame(1, $campaign->donors_count);
    }

    public function test_a_refund_takes_the_donation_out_of_the_total(): void
    {
        $this->deliver($this->event('PAYMENT.CAPTURE.COMPLETED'))->assertOk();
        $this->assertSame(4000, $this->campaign->fresh()->raised_amount);

        $refund = [
            'id' => 'WH-EVENT-REFUND',
            'event_type' => 'PAYMENT.CAPTURE.REFUNDED',
            'resource' => [
                'id' => 'REFUND1234',
                'amount' => ['currency_code' => 'EUR', 'value' => '40.00'],
                'links' => [['rel' => 'up', 'href' => 'https://api.sandbox.paypal.com/v2/payments/captures/'.$this->donation->fresh()->paypal_capture_id]],
            ],
        ];
        $this->deliver($refund)->assertOk();
        $this->deliver($refund)->assertOk();

        $this->assertSame('refunded', $this->donation->fresh()->status);
        $campaign = $this->campaign->fresh();
        $this->assertSame(0, $campaign->raised_amount);
        $this->assertSame(0, $campaign->donors_count);
    }

    public function test_a_reversal_and_a_denial_are_handled(): void
    {
        $this->deliver($this->event('PAYMENT.CAPTURE.DENIED'))->assertOk();
        $this->assertSame('failed', $this->donation->fresh()->status);

        $this->deliver($this->event('PAYMENT.CAPTURE.COMPLETED', 'WH-EVENT-3'))->assertOk();
        $this->assertSame('completed', $this->donation->fresh()->status);

        $this->deliver($this->event('PAYMENT.CAPTURE.REVERSED', 'WH-EVENT-4'))->assertOk();
        $this->assertSame('refunded', $this->donation->fresh()->status);
        $this->assertSame(0, $this->campaign->fresh()->raised_amount);
    }

    public function test_no_header_can_take_the_place_of_the_event_sent_for_checking(): void
    {
        $event = $this->event('PAYMENT.CAPTURE.COMPLETED');
        $this->deliver($event, '__EVENT__');

        Http::assertSent(fn (Request $r) => str_ends_with($r->url(), '/v1/notifications/verify-webhook-signature')
            && $r->data()['auth_algo'] === '__EVENT__'
            && $r->data()['webhook_event'] === $event);
    }

    public function test_a_reversal_as_paypal_sends_it_takes_the_donation_out_of_the_total(): void
    {
        $this->deliver($this->event('PAYMENT.CAPTURE.COMPLETED'))->assertOk();
        $captureId = $this->donation->fresh()->paypal_capture_id;
        $this->assertNotNull($captureId);
        $this->assertSame(4000, $this->campaign->fresh()->raised_amount);

        // A reversal (a chargeback) carries a refund resource: its own id, and
        // its capture only in the "up" link — no order id, no custom_id.
        $this->deliver([
            'id' => 'WH-EVENT-REVERSAL',
            'event_type' => 'PAYMENT.CAPTURE.REVERSED',
            'resource_type' => 'refund',
            'resource' => [
                'id' => '1Y107995YT783435V',
                'status' => 'COMPLETED',
                'amount' => ['currency_code' => 'EUR', 'value' => '40.00'],
                'note_to_payer' => 'Payment reversed',
                'links' => [
                    ['rel' => 'self', 'method' => 'GET', 'href' => 'https://api.sandbox.paypal.com/v2/payments/refunds/1Y107995YT783435V'],
                    ['rel' => 'up', 'method' => 'GET', 'href' => 'https://api.sandbox.paypal.com/v2/payments/captures/'.$captureId],
                ],
            ],
        ])->assertOk();

        $this->assertSame('refunded', $this->donation->fresh()->status);
        $campaign = $this->campaign->fresh();
        $this->assertSame(0, $campaign->raised_amount);
        $this->assertSame(0, $campaign->donors_count);
    }

    public function test_without_a_webhook_id_every_delivery_is_refused(): void
    {
        config(['fundraising.paypal.webhook_id' => null]);

        $this->deliver($this->event('PAYMENT.CAPTURE.COMPLETED'))->assertStatus(400);
        $this->assertSame('pending', $this->donation->fresh()->status);
    }
}
