<?php

namespace Tests\Feature\Fundraising;

use App\Models\Donation;
use App\Notifications\DonationThanks;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\Client\Request;
use Illuminate\Notifications\AnonymousNotifiable;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Notification;
use Inertia\Testing\AssertableInertia as Assert;
use Tests\TestCase;

class PayPalDonationTest extends TestCase
{
    use FundraisingFixtures, RefreshDatabase;

    private const ORDER = '5O190127TN364715T';

    /** @var array<string, mixed>|null What the fake PayPal answers to a capture. */
    private ?array $captureAnswer = null;

    private int $captureCalls = 0;

    protected function setUp(): void
    {
        parent::setUp();
        $this->setUpFundraising();
        Notification::fake();

        Http::fake(function (Request $request) {
            $url = $request->url();
            if (str_ends_with($url, '/v1/oauth2/token')) {
                return Http::response(['access_token' => 'A21-test-token', 'expires_in' => 32400]);
            }
            if ($request->method() === 'POST' && str_ends_with($url, '/v2/checkout/orders')) {
                return Http::response(['id' => self::ORDER, 'status' => 'CREATED'], 201);
            }
            if (str_ends_with($url, '/v2/checkout/orders/'.self::ORDER.'/capture')) {
                $this->captureCalls++;

                return Http::response($this->captureAnswer ?? [], 201);
            }

            return Http::response(['name' => 'NOT_FOUND'], 404);
        });
    }

    private function startDonation(array $overrides = []): Donation
    {
        $this->postJson('/campaigns/nouveau-toit/donations/paypal', $this->donor($overrides))
            ->assertOk()
            ->assertJsonPath('order_id', self::ORDER);

        return Donation::query()->where('paypal_order_id', self::ORDER)->firstOrFail();
    }

    public function test_the_order_pays_the_mosques_verified_account_the_server_amount(): void
    {
        $donation = $this->startDonation(['amount' => 2500]);

        $this->assertSame('pending', $donation->status);
        $this->assertSame('paypal', $donation->method);
        $this->assertSame(2500, $donation->amount);

        Http::assertSent(function (Request $request) use ($donation) {
            if (! str_ends_with($request->url(), '/v2/checkout/orders')) {
                return false;
            }
            $unit = $request->data()['purchase_units'][0];

            return $request->data()['intent'] === 'CAPTURE'
                && $unit['amount'] === ['currency_code' => 'EUR', 'value' => '25.00']
                && $unit['payee'] === ['email_address' => 'tresorier@mosquee-test.fr']
                && $unit['custom_id'] === $donation->reference
                && $unit['description'] === 'Nouveau toit'
                // PayPal's page names the mosque, never the platform, as the one being paid.
                && $request->data()['application_context']['brand_name'] === 'Mosquée Test'
                && $request->hasHeader('PayPal-Request-Id', 'order-'.$donation->reference)
                && $request->hasHeader('Authorization', 'Bearer A21-test-token');
        });
    }

    public function test_a_merchant_id_is_preferred_as_payee(): void
    {
        $this->paypalPayout->forceFill(['paypal_merchant_id' => 'ABCDEFGHJK234'])->save();
        $this->startDonation();

        Http::assertSent(fn (Request $r) => str_ends_with($r->url(), '/v2/checkout/orders')
            && $r->data()['purchase_units'][0]['payee'] === ['merchant_id' => 'ABCDEFGHJK234']);
    }

    public function test_amounts_outside_the_limits_are_refused(): void
    {
        $this->postJson('/campaigns/nouveau-toit/donations/paypal', $this->donor(['amount' => 99]))->assertUnprocessable()->assertJsonValidationErrors('amount');
        $this->postJson('/campaigns/nouveau-toit/donations/paypal', $this->donor(['amount' => 10_000_001]))->assertUnprocessable()->assertJsonValidationErrors('amount');
        $this->postJson('/campaigns/nouveau-toit/donations/paypal', $this->donor(['donor_email' => 'not-an-email']))->assertUnprocessable()->assertJsonValidationErrors('donor_email');
        $this->assertDatabaseCount('donations', 0);
        Http::assertNothingSent();
    }

    public function test_an_unverified_paypal_account_is_never_paid(): void
    {
        $this->paypalPayout->forceFill(['verified_at' => null])->save();

        $this->postJson('/campaigns/nouveau-toit/donations/paypal', $this->donor())->assertUnprocessable();
        $this->assertDatabaseCount('donations', 0);
        Http::assertNothingSent();
    }

    public function test_a_capture_completes_the_donation_once_and_counts_it(): void
    {
        $donation = $this->startDonation();
        $this->captureAnswer = $this->paypalOrder(self::ORDER, $donation->reference);

        $first = $this->postJson('/campaigns/nouveau-toit/donations/paypal/'.self::ORDER.'/capture')->assertOk();
        $first->assertJsonPath('status', 'completed');
        $this->assertStringContainsString('/donations/'.$donation->reference, (string) $first->json('redirect'));

        // Repeats (a double click, a retry) change nothing and do not call PayPal again.
        $this->postJson('/campaigns/nouveau-toit/donations/paypal/'.self::ORDER.'/capture')->assertOk()->assertJsonPath('status', 'completed');
        $this->postJson('/campaigns/nouveau-toit/donations/paypal/'.self::ORDER.'/capture')->assertOk();

        $this->assertSame(1, $this->captureCalls);
        $donation->refresh();
        $this->assertSame('completed', $donation->status);
        $this->assertNotNull($donation->paypal_capture_id);
        $campaign = $this->campaign->fresh();
        $this->assertSame(2500, $campaign->raised_amount);
        $this->assertSame(1, $campaign->donors_count);
        $this->assertSame(0, $campaign->pledged_amount);

        Notification::assertSentTimes(DonationThanks::class, 1);
        Notification::assertSentOnDemand(DonationThanks::class, fn ($n, $channels, AnonymousNotifiable $notifiable) => $notifiable->routes['mail'] === ['yasmine@example.com' => 'Yasmine B.']);
    }

    public function test_a_capture_for_another_amount_is_refused(): void
    {
        $donation = $this->startDonation();
        $this->captureAnswer = $this->paypalOrder(self::ORDER, $donation->reference, '2.50');

        $this->postJson('/campaigns/nouveau-toit/donations/paypal/'.self::ORDER.'/capture')->assertUnprocessable();
        $this->assertSame('failed', $donation->fresh()->status);
        $this->assertSame(0, $this->campaign->fresh()->raised_amount);
    }

    public function test_a_capture_in_another_currency_is_refused(): void
    {
        $donation = $this->startDonation();
        $this->captureAnswer = $this->paypalOrder(self::ORDER, $donation->reference, '25.00', currency: 'USD');

        $this->postJson('/campaigns/nouveau-toit/donations/paypal/'.self::ORDER.'/capture')->assertUnprocessable();
        $this->assertSame('failed', $donation->fresh()->status);
    }

    public function test_a_capture_paid_to_someone_else_is_refused(): void
    {
        $donation = $this->startDonation();
        $this->captureAnswer = $this->paypalOrder(self::ORDER, $donation->reference, '25.00', ['email_address' => 'thief@example.com', 'merchant_id' => 'THIEF']);

        $this->postJson('/campaigns/nouveau-toit/donations/paypal/'.self::ORDER.'/capture')->assertUnprocessable();
        $this->assertSame('failed', $donation->fresh()->status);
        $this->assertSame(0, $this->campaign->fresh()->donors_count);
        Notification::assertNothingSent();
    }

    public function test_a_pending_capture_waits_for_paypal(): void
    {
        $donation = $this->startDonation();
        $this->captureAnswer = $this->paypalOrder(self::ORDER, $donation->reference, status: 'PENDING');
        $this->captureAnswer['status'] = 'COMPLETED';

        $this->postJson('/campaigns/nouveau-toit/donations/paypal/'.self::ORDER.'/capture')->assertOk()->assertJsonPath('status', 'pending');
        $this->assertSame('pending', $donation->fresh()->status);
        $this->assertSame(0, $this->campaign->fresh()->raised_amount);
    }

    public function test_an_unknown_order_is_not_found(): void
    {
        $this->postJson('/campaigns/nouveau-toit/donations/paypal/ABCDEFGH1234/capture')->assertNotFound();
    }

    public function test_cancelling_the_paypal_window_drops_the_pending_donation(): void
    {
        $donation = $this->startDonation();
        $this->postJson('/campaigns/nouveau-toit/donations/paypal/'.self::ORDER.'/cancel')->assertOk();

        $this->assertSame('cancelled', $donation->fresh()->status);
    }

    public function test_without_paypal_credentials_paypal_is_not_offered(): void
    {
        config(['fundraising.paypal.client_id' => null, 'fundraising.paypal.client_secret' => null]);

        $this->get('/campaigns/nouveau-toit')
            ->assertOk()
            ->assertInertia(fn (Assert $page) => $page
                ->component('campaigns/show')
                ->where('methods.paypal', false)
                ->where('methods.bank', true)
                ->where('paypal', null));

        $this->postJson('/campaigns/nouveau-toit/donations/paypal', $this->donor())->assertUnprocessable();
        Http::assertNothingSent();
    }

    public function test_the_campaign_page_offers_paypal_with_the_public_client_id_only(): void
    {
        $this->get('/campaigns/nouveau-toit')
            ->assertOk()
            ->assertDontSee('test-client-secret')
            ->assertInertia(fn (Assert $page) => $page
                ->where('methods.paypal', true)
                ->where('paypal.client_id', 'test-client-id')
                ->where('paypal.merchant', 'tresorier@mosquee-test.fr'));
    }

    public function test_closed_campaigns_take_no_donation(): void
    {
        $this->campaign->forceFill(['status' => 'closed'])->save();

        $this->postJson('/campaigns/nouveau-toit/donations/paypal', $this->donor())->assertUnprocessable();
        $this->post('/campaigns/nouveau-toit/donations/bank', $this->donor())->assertSessionHasErrors('method');
        $this->assertDatabaseCount('donations', 0);
    }
}
