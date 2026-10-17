<?php

namespace Tests\Feature\Fundraising;

use App\Models\Donation;
use App\Notifications\CampaignApproved;
use App\Notifications\CampaignRejected;
use App\Notifications\CampaignSubmitted;
use App\Notifications\DonationBankInstructions;
use App\Notifications\DonationThanks;
use App\Notifications\PayoutVerified;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Notifications\AnonymousNotifiable;
use Illuminate\Support\Facades\Notification;
use Tests\TestCase;

class FundraisingEmailTest extends TestCase
{
    use FundraisingFixtures, RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        $this->setUpFundraising(paypalConfigured: false);
    }

    private function donation(array $attributes = []): Donation
    {
        $donation = Donation::factory()->create([
            'campaign_id' => $this->campaign->id,
            'mosque_id' => $this->mosque->id,
            'amount' => 2550,
            'reference' => 'ST-ABCD-2345',
            'donor_name' => 'Yasmine',
            ...$attributes,
        ]);
        $donation->forceFill(['locale' => 'fr'])->save();

        return $donation;
    }

    public function test_bank_instructions_carry_the_account_amount_and_reference_in_the_donors_language(): void
    {
        app()->setLocale('fr');
        $html = (string) (new DonationBankInstructions($this->donation()))->toMail(new AnonymousNotifiable)->render();

        $this->assertStringContainsString('FR76 3000 6000 0112 3456 7890 189', $html);
        $this->assertStringContainsString('ST-ABCD-2345', $html);
        $this->assertStringContainsString('25,50', $html);
        $this->assertStringContainsString('Association Mosquée Test', $html);
        $this->assertStringContainsString('reçus fiscaux', $html);
        $this->assertStringContainsString('/donations/ST-ABCD-2345?signature=', $html);
    }

    public function test_text_typed_by_people_cannot_inject_links(): void
    {
        $html = (string) (new DonationThanks($this->donation(['donor_name' => '[Win](https://evil.example) **now**'])))
            ->toMail(new AnonymousNotifiable)->render();

        $this->assertStringNotContainsString('href="https://evil.example"', $html);
        $this->assertStringNotContainsString('<strong>now</strong>', $html);
    }

    public function test_the_bank_pledge_email_goes_to_the_donor_in_their_language(): void
    {
        Notification::fake();
        $this->post('/campaigns/nouveau-toit/donations/bank', $this->donor(), ['Accept-Language' => 'ar'])->assertRedirect();

        Notification::assertSentOnDemand(DonationBankInstructions::class, fn ($notification, $channels, $notifiable) => $notification->locale === 'ar'
            && $notifiable->routes['mail'] === ['yasmine@example.com' => 'Yasmine B.']);
    }

    public function test_every_fundraising_email_renders_in_every_language(): void
    {
        $donation = $this->donation();
        $this->campaign->forceFill(['review_note' => "Merci.\nDeuxième paragraphe."])->save();
        $notifications = [
            new DonationThanks($donation),
            new DonationBankInstructions($donation),
            new CampaignSubmitted($this->campaign),
            new CampaignApproved($this->campaign),
            new CampaignRejected($this->campaign),
            new PayoutVerified($this->bankPayout),
        ];

        foreach (['en', 'fr', 'ar'] as $locale) {
            app()->setLocale($locale);
            foreach ($notifications as $notification) {
                $html = (string) $notification->toMail($this->manager)->render();
                $this->assertStringNotContainsString('fundraising.', $html, $notification::class." ($locale) shows a raw key");
            }
        }
    }
}
