<?php

namespace Tests\Feature\Fundraising;

use App\Http\Controllers\Fundraising\DonationReceiptController;
use App\Models\Donation;
use App\Models\Mosque;
use App\Models\User;
use App\Notifications\DonationBankInstructions;
use App\Notifications\DonationThanks;
use App\Services\Fundraising\DonationReference;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Notification;
use Inertia\Testing\AssertableInertia as Assert;
use Tests\TestCase;

class BankDonationTest extends TestCase
{
    use FundraisingFixtures, RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        $this->setUpFundraising(paypalConfigured: false);
        Notification::fake();
    }

    private function pledge(array $overrides = []): Donation
    {
        $response = $this->post('/campaigns/nouveau-toit/donations/bank', $this->donor($overrides));
        $donation = Donation::query()->latest('id')->firstOrFail();
        $response->assertRedirect(DonationReceiptController::link($donation->reference));

        return $donation;
    }

    public function test_a_bank_pledge_is_pending_with_a_unique_reference_and_counts_as_pledged(): void
    {
        $first = $this->pledge(['amount' => 5000]);
        $second = $this->pledge(['amount' => 1500]);

        $this->assertMatchesRegularExpression(DonationReference::PATTERN, $first->reference);
        $this->assertNotSame($first->reference, $second->reference);
        $this->assertSame('pending', $first->status);
        $this->assertSame('bank', $first->method);

        $campaign = $this->campaign->fresh();
        $this->assertSame(6500, $campaign->pledged_amount);
        $this->assertSame(0, $campaign->raised_amount);
        $this->assertSame(0, $campaign->donors_count);
        Notification::assertSentOnDemandTimes(DonationBankInstructions::class, 2);
    }

    public function test_one_email_address_cannot_be_flooded_with_instructions(): void
    {
        for ($i = 0; $i < 5; $i++) {
            $this->post('/campaigns/nouveau-toit/donations/bank', $this->donor(['donor_email' => 'victim@example.com']))->assertRedirect();
        }
        $this->post('/campaigns/nouveau-toit/donations/bank', $this->donor(['donor_email' => 'Victim@Example.com']))
            ->assertSessionHasErrors('donor_email');

        $this->assertDatabaseCount('donations', 5);
        Notification::assertSentOnDemandTimes(DonationBankInstructions::class, 5);
    }

    public function test_references_are_unique_over_many_pledges(): void
    {
        $references = [];
        for ($i = 0; $i < 200; $i++) {
            $references[] = DonationReference::generate();
        }
        $this->assertCount(200, array_unique($references));
    }

    public function test_the_instructions_page_shows_the_mosques_account_amount_and_reference(): void
    {
        $donation = $this->pledge(['amount' => 5000]);

        $this->get(DonationReceiptController::link($donation->reference))
            ->assertOk()
            ->assertInertia(fn (Assert $page) => $page
                ->component('campaigns/donation')
                ->where('donation.reference', $donation->reference)
                ->where('donation.amount', 5000)
                ->where('bank.iban', 'FR76 3000 6000 0112 3456 7890 189')
                ->where('bank.account_holder', 'Association Mosquée Test')
                ->where('bank.bic', 'AGRIFRPP')
                ->missing('donation.donor_email'));
    }

    public function test_the_instructions_page_needs_a_valid_signature(): void
    {
        $donation = $this->pledge();

        $this->get('/donations/'.$donation->reference)->assertForbidden();
        $this->get('/donations/'.$donation->reference.'?signature=forged')->assertForbidden();
    }

    public function test_an_unverified_bank_account_is_not_offered(): void
    {
        $this->bankPayout->forceFill(['verified_at' => null])->save();

        $this->post('/campaigns/nouveau-toit/donations/bank', $this->donor())->assertSessionHasErrors('method');
        $this->assertDatabaseCount('donations', 0);
    }

    public function test_signed_in_donors_are_linked_and_prefilled(): void
    {
        $user = User::factory()->create(['name' => 'Karim', 'email' => 'karim@example.com']);

        $this->actingAs($user)->post('/campaigns/nouveau-toit/donations/bank', ['amount' => 2000])->assertRedirect();
        $donation = Donation::query()->firstOrFail();
        $this->assertSame($user->id, $donation->user_id);
        $this->assertSame('karim@example.com', $donation->donor_email);
        $this->assertSame('Karim', $donation->donor_name);

        $this->actingAs($user)->get('/me/donations')
            ->assertOk()
            ->assertInertia(fn (Assert $page) => $page
                ->component('me/donations')
                ->where('donations.data.0.reference', $donation->reference)
                ->where('donations.data.0.status', 'pending'));
    }

    public function test_my_donations_needs_an_account(): void
    {
        $this->get('/me/donations')->assertRedirect('/login');
    }

    public function test_the_manager_confirms_a_transfer_once_and_totals_stay_right(): void
    {
        $donation = $this->pledge(['amount' => 5000]);
        $url = "/manage/{$this->mosque->slug}/donations/{$donation->id}/confirm";

        $this->actingAs($this->manager)->post($url)->assertRedirect();
        $this->actingAs($this->manager)->post($url)->assertRedirect();
        $this->actingAs($this->manager)->post($url)->assertRedirect();

        $donation->refresh();
        $this->assertSame('completed', $donation->status);
        $this->assertSame($this->manager->id, $donation->confirmed_by);
        $campaign = $this->campaign->fresh();
        $this->assertSame(5000, $campaign->raised_amount);
        $this->assertSame(0, $campaign->pledged_amount);
        $this->assertSame(1, $campaign->donors_count);
        Notification::assertSentOnDemandTimes(DonationThanks::class, 1);
    }

    public function test_the_manager_cancels_a_transfer_that_never_came(): void
    {
        $donation = $this->pledge(['amount' => 5000]);

        $this->actingAs($this->manager)->post("/manage/{$this->mosque->slug}/donations/{$donation->id}/cancel")->assertRedirect();

        $this->assertSame('cancelled', $donation->fresh()->status);
        $this->assertSame(0, $this->campaign->fresh()->pledged_amount);

        // A cancelled pledge can no longer be cancelled; confirming it later is allowed (the money came after all).
        $this->actingAs($this->manager)->post("/manage/{$this->mosque->slug}/donations/{$donation->id}/confirm");
        $this->assertSame(5000, $this->campaign->fresh()->raised_amount);
    }

    public function test_only_the_mosques_managers_confirm_or_cancel(): void
    {
        $donation = $this->pledge(['amount' => 5000]);
        $stranger = User::factory()->create();
        $otherManager = User::factory()->create();
        Mosque::factory()->create()->managers()->attach($otherManager, ['role' => 'owner']);

        $this->post("/manage/{$this->mosque->slug}/donations/{$donation->id}/confirm")->assertRedirect('/login');
        $this->actingAs($stranger)->post("/manage/{$this->mosque->slug}/donations/{$donation->id}/confirm")->assertForbidden();
        $this->actingAs($otherManager)->post("/manage/{$this->mosque->slug}/donations/{$donation->id}/cancel")->assertForbidden();

        // A manager of another mosque cannot reach this donation through their own mosque either.
        $other = $otherManager->managedMosques()->first();
        $this->actingAs($otherManager)->post("/manage/{$other->slug}/donations/{$donation->id}/confirm")->assertNotFound();

        $this->assertSame('pending', $donation->fresh()->status);
    }

    public function test_paypal_donations_cannot_be_confirmed_by_hand(): void
    {
        $donation = Donation::factory()->create(['campaign_id' => $this->campaign->id, 'mosque_id' => $this->mosque->id, 'method' => 'paypal']);

        $this->actingAs($this->manager)->post("/manage/{$this->mosque->slug}/donations/{$donation->id}/confirm")->assertNotFound();
        $this->assertSame('pending', $donation->fresh()->status);
    }

    public function test_totals_stay_right_when_many_donations_settle(): void
    {
        $amounts = [1000, 2000, 3000, 4000, 5000];
        $donations = array_map(fn (int $amount) => $this->pledge(['amount' => $amount]), $amounts);
        $this->assertSame(15000, $this->campaign->fresh()->pledged_amount);

        foreach ($donations as $i => $donation) {
            $action = $i % 2 === 0 ? 'confirm' : 'cancel';
            // Each click twice, as an impatient manager would.
            $this->actingAs($this->manager)->post("/manage/{$this->mosque->slug}/donations/{$donation->id}/{$action}");
            $this->actingAs($this->manager)->post("/manage/{$this->mosque->slug}/donations/{$donation->id}/{$action}");
        }

        $campaign = $this->campaign->fresh();
        $this->assertSame(1000 + 3000 + 5000, $campaign->raised_amount);
        $this->assertSame(3, $campaign->donors_count);
        $this->assertSame(0, $campaign->pledged_amount);
    }
}
