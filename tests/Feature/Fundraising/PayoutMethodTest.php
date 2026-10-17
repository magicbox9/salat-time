<?php

namespace Tests\Feature\Fundraising;

use App\Models\MosquePayoutMethod;
use App\Models\User;
use App\Notifications\PayoutVerified;
use App\Services\Fundraising\ReviewVersion;
use App\Services\Payments\BankAccount;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Notification;
use Inertia\Testing\AssertableInertia as Assert;
use Tests\TestCase;

class PayoutMethodTest extends TestCase
{
    use FundraisingFixtures, RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        $this->setUpFundraising();
        Notification::fake();
    }

    private function url(string $suffix = ''): string
    {
        return "/manage/{$this->mosque->slug}/payouts".$suffix;
    }

    public function test_iban_checksums_and_lengths(): void
    {
        $this->assertTrue(BankAccount::isValidIban('FR76 3000 6000 0112 3456 7890 189'));
        $this->assertTrue(BankAccount::isValidIban('de89370400440532013000'));
        $this->assertTrue(BankAccount::isValidIban('GB82 WEST 1234 5698 7654 32'));
        $this->assertFalse(BankAccount::isValidIban('FR76 3000 6000 0112 3456 7890 188'));   // checksum
        $this->assertFalse(BankAccount::isValidIban('FR76 3000 6000 0112 3456 7890 18'));    // length
        $this->assertFalse(BankAccount::isValidIban('not an iban'));
        $this->assertTrue(BankAccount::isValidBic('AGRIFRPP'));
        $this->assertTrue(BankAccount::isValidBic('agrifrpp882'));
        $this->assertFalse(BankAccount::isValidBic('AGRI-FR'));
    }

    public function test_a_wrong_iban_is_refused(): void
    {
        $this->actingAs($this->manager)->put($this->url('/bank'), [
            'account_holder' => 'Association', 'iban' => 'FR7630006000011234567890188', 'bic' => 'AGRIFRPP',
        ])->assertSessionHasErrors('iban');
        $this->assertSame(self::IBAN, $this->bankPayout->fresh()->iban);
    }

    public function test_a_wrong_bic_is_refused(): void
    {
        $this->actingAs($this->manager)->put($this->url('/bank'), [
            'account_holder' => 'Association', 'iban' => self::IBAN, 'bic' => 'XX',
        ])->assertSessionHasErrors('bic');
    }

    public function test_changing_an_account_resets_its_verification_and_keeps_the_iban_encrypted(): void
    {
        $this->actingAs($this->manager)->put($this->url('/bank'), [
            'account_holder' => 'Association Mosquée Test',
            'iban' => 'DE89 3704 0044 0532 0130 00',
            'bic' => 'COBADEFFXXX',
            'bank_name' => 'Commerzbank',
        ])->assertRedirect();

        $payout = $this->bankPayout->fresh();
        $this->assertNull($payout->verified_at);
        $this->assertSame('DE89370400440532013000', $payout->iban);
        $raw = DB::table('mosque_payout_methods')->where('id', $payout->id)->value('iban');
        $this->assertStringNotContainsString('DE89', (string) $raw);
    }

    public function test_saving_the_same_details_keeps_the_verification(): void
    {
        $this->actingAs($this->manager)->put($this->url('/bank'), [
            'account_holder' => 'Association Mosquée Test', 'iban' => '', 'bic' => 'AGRIFRPP', 'bank_name' => 'Crédit Test',
        ])->assertRedirect();

        $this->assertNotNull($this->bankPayout->fresh()->verified_at);
        $this->assertSame(self::IBAN, $this->bankPayout->fresh()->iban);
    }

    public function test_paypal_needs_an_email_or_a_merchant_id(): void
    {
        $this->actingAs($this->manager)->post($this->url(), ['type' => 'paypal'])->assertSessionHasErrors('paypal_email');
        $this->actingAs($this->manager)->post($this->url(), ['type' => 'paypal', 'paypal_merchant_id' => 'short'])->assertSessionHasErrors('paypal_merchant_id');
        $this->actingAs($this->manager)->post($this->url(), ['type' => 'paypal', 'paypal_email' => 'Dons@Mosquee-Test.fr'])->assertRedirect();

        $payout = $this->paypalPayout->fresh();
        $this->assertSame('dons@mosquee-test.fr', $payout->paypal_email);
        $this->assertNull($payout->verified_at);
    }

    public function test_the_manager_sees_the_iban_masked_only(): void
    {
        $this->actingAs($this->manager)->get($this->url())
            ->assertOk()
            ->assertDontSee('30006000011234567890')
            ->assertInertia(fn (Assert $page) => $page
                ->component('fundraising/payouts')
                ->where('bank.iban_masked', 'FR76 •••• •••• 0189')
                ->missing('bank.iban'));
    }

    public function test_others_cannot_change_a_mosques_accounts(): void
    {
        $stranger = User::factory()->create();
        $this->actingAs($stranger)->post($this->url(), ['type' => 'paypal', 'paypal_email' => 'thief@example.com'])->assertForbidden();
        $this->actingAs($stranger)->delete($this->url('/paypal'))->assertForbidden();
        $this->assertSame('tresorier@mosquee-test.fr', $this->paypalPayout->fresh()->paypal_email);
    }

    public function test_admins_reveal_the_full_iban_on_request_and_it_is_logged(): void
    {
        $admin = $this->admin();
        Log::spy();

        $this->actingAs($admin)->get('/admin/fundraising/payouts?state=verified')
            ->assertOk()
            ->assertDontSee('30006000011234567890');

        $this->actingAs($admin)->postJson("/admin/fundraising/payouts/{$this->bankPayout->id}/reveal")
            ->assertOk()
            ->assertJsonPath('iban', 'FR76 3000 6000 0112 3456 7890 189');

        Log::shouldHaveReceived('info')->withArgs(fn (string $message, array $context) => str_contains($message, 'revealed')
            && $context['admin_id'] === $admin->id && $context['payout_method_id'] === $this->bankPayout->id);

        $this->actingAs($this->manager)->postJson("/admin/fundraising/payouts/{$this->bankPayout->id}/reveal")->assertForbidden();
    }

    public function test_admins_verify_an_account_and_the_managers_are_told(): void
    {
        $admin = $this->admin();
        $payout = new MosquePayoutMethod(['mosque_id' => $this->mosque->id, 'type' => 'paypal', 'paypal_email' => 'new@example.com']);
        $this->paypalPayout->delete();
        $payout->save();

        $verify = "/admin/fundraising/payouts/{$payout->id}/verify?version=".ReviewVersion::payout($payout);
        $this->actingAs($this->manager)->post($verify)->assertForbidden();
        $this->actingAs($admin)->post($verify)->assertRedirect();

        $payout->refresh();
        $this->assertNotNull($payout->verified_at);
        $this->assertSame($admin->id, $payout->verified_by);
        Notification::assertSentTo($this->manager, PayoutVerified::class);

        $this->actingAs($admin)->delete("/admin/fundraising/payouts/{$payout->id}/verify")->assertRedirect();
        $this->assertNull($payout->fresh()->verified_at);
    }

    public function test_an_account_changed_during_its_review_is_not_verified(): void
    {
        $admin = $this->admin();
        $this->bankPayout->forceFill(['verified_at' => null])->save();

        $this->actingAs($admin)->get('/admin/fundraising/payouts')->assertOk()
            ->assertInertia(fn (Assert $page) => $page->where('payouts.data.0.version', ReviewVersion::payout($this->bankPayout->fresh())));
        $reviewed = "/admin/fundraising/payouts/{$this->bankPayout->id}/verify?version=".ReviewVersion::payout($this->bankPayout->fresh());

        // The IBAN is swapped after the admin read the old one.
        $this->actingAs($this->manager)->put("/manage/{$this->mosque->slug}/payouts/bank", [
            'account_holder' => 'Association Mosquée Test',
            'iban' => 'DE89 3704 0044 0532 0130 00',
            'bic' => 'COBADEFFXXX',
        ])->assertRedirect();

        $this->actingAs($admin)->post($reviewed)->assertRedirect()
            ->assertInertiaFlash('toast.message', ui('fundraising.admin_payout_changed'));
        $this->assertNull($this->bankPayout->fresh()->verified_at);
        Notification::assertNotSentTo($this->manager, PayoutVerified::class);

        // Without a version, nothing is verified either.
        $this->actingAs($admin)->post("/admin/fundraising/payouts/{$this->bankPayout->id}/verify")->assertRedirect();
        $this->assertNull($this->bankPayout->fresh()->verified_at);

        // The new details, once reviewed, can be verified.
        $this->actingAs($admin)->post("/admin/fundraising/payouts/{$this->bankPayout->id}/verify?version=".ReviewVersion::payout($this->bankPayout->fresh()))
            ->assertRedirect();
        $this->assertNotNull($this->bankPayout->fresh()->verified_at);
    }
}
