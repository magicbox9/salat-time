<?php

namespace Tests\Feature\Fundraising;

use App\Models\Campaign;
use App\Models\Mosque;
use App\Models\MosquePayoutMethod;
use App\Models\User;
use Illuminate\Support\Facades\Http;

/** A verified mosque with a manager, verified PayPal and bank accounts, and an open campaign. */
trait FundraisingFixtures
{
    protected const API = 'https://api-m.sandbox.paypal.com';

    /** A valid French IBAN (checksum 76). */
    protected const IBAN = 'FR7630006000011234567890189';

    protected Mosque $mosque;

    protected User $manager;

    protected Campaign $campaign;

    protected MosquePayoutMethod $paypalPayout;

    protected MosquePayoutMethod $bankPayout;

    protected function setUpFundraising(bool $paypalConfigured = true): void
    {
        $this->withoutVite();
        config([
            'fundraising.paypal.mode' => 'sandbox',
            'fundraising.paypal.client_id' => $paypalConfigured ? 'test-client-id' : null,
            'fundraising.paypal.client_secret' => $paypalConfigured ? 'test-client-secret' : null,
            'fundraising.paypal.webhook_id' => $paypalConfigured ? 'WH-TEST-123' : null,
        ]);
        Http::preventStrayRequests();

        $this->mosque = Mosque::factory()->verified()->create(['name' => 'Mosquée Test']);
        $this->manager = User::factory()->create();
        $this->mosque->managers()->attach($this->manager, ['role' => 'owner']);

        $this->paypalPayout = $this->payout('paypal', ['paypal_email' => 'tresorier@mosquee-test.fr']);
        $this->bankPayout = $this->payout('bank', [
            'account_holder' => 'Association Mosquée Test',
            'iban' => self::IBAN,
            'bic' => 'AGRIFRPP',
            'bank_name' => 'Crédit Test',
        ]);

        $this->campaign = Campaign::factory()->active()->create([
            'mosque_id' => $this->mosque->id,
            'title' => 'Nouveau toit',
            'slug' => 'nouveau-toit',
            'goal_amount' => 1_000_000,
        ]);
    }

    /** @param  array<string, mixed>  $fields */
    protected function payout(string $type, array $fields, bool $verified = true): MosquePayoutMethod
    {
        $payout = new MosquePayoutMethod(['mosque_id' => $this->mosque->id, 'type' => $type, ...$fields]);
        $payout->forceFill(['verified_at' => $verified ? now() : null])->save();

        return $payout;
    }

    /** Signs the test client out (actingAs() otherwise lasts for the whole test). */
    protected function asGuest(): static
    {
        $this->app['auth']->forgetGuards();

        return $this;
    }

    protected function admin(): User
    {
        $admin = User::factory()->create();
        $admin->forceFill(['is_admin' => true])->save();

        return $admin;
    }

    /** @return array<string, mixed> */
    protected function donor(array $overrides = []): array
    {
        return [
            'amount' => 2500,
            'donor_name' => 'Yasmine B.',
            'donor_email' => 'yasmine@example.com',
            'anonymous' => false,
            'message' => 'Barakallahu fikum',
            ...$overrides,
        ];
    }

    /**
     * An order as PayPal returns it after a capture.
     *
     * @return array<string, mixed>
     */
    protected function paypalOrder(string $orderId, string $reference, string $value = '25.00', array $payee = ['email_address' => 'tresorier@mosquee-test.fr', 'merchant_id' => 'MERCHANT12345'], string $currency = 'EUR', string $status = 'COMPLETED'): array
    {
        return [
            'id' => $orderId,
            'status' => $status,
            'purchase_units' => [[
                'reference_id' => $reference,
                'custom_id' => $reference,
                'amount' => ['currency_code' => $currency, 'value' => $value],
                'payee' => $payee,
                'payments' => ['captures' => [[
                    'id' => 'CAPTURE'.substr($orderId, 0, 8),
                    'status' => $status,
                    'amount' => ['currency_code' => $currency, 'value' => $value],
                    'custom_id' => $reference,
                ]]],
            ]],
        ];
    }

    protected function fakeToken(): array
    {
        return [self::API.'/v1/oauth2/token' => Http::response(['access_token' => 'A21-test-token', 'expires_in' => 32400])];
    }
}
