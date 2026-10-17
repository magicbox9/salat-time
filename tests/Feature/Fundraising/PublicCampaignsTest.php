<?php

namespace Tests\Feature\Fundraising;

use App\Models\Campaign;
use App\Models\Donation;
use App\Models\Mosque;
use App\Services\Fundraising\DonationCsv;
use App\Services\Fundraising\DonationLedger;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Notification;
use Inertia\Testing\AssertableInertia as Assert;
use Tests\TestCase;

class PublicCampaignsTest extends TestCase
{
    use FundraisingFixtures, RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        $this->setUpFundraising(paypalConfigured: false);
        Notification::fake();
    }

    private function completed(int $amount, array $attributes = []): Donation
    {
        $donation = Donation::factory()->create([
            'campaign_id' => $this->campaign->id,
            'mosque_id' => $this->mosque->id,
            'amount' => $amount,
            ...$attributes,
        ]);
        app(DonationLedger::class)->complete($donation);

        return $donation;
    }

    public function test_progress_json_reports_the_live_figures_without_emails(): void
    {
        $this->completed(3000, ['donor_name' => 'Amine', 'donor_email' => 'amine@example.com', 'message' => 'Courage']);
        $this->completed(2000, ['donor_name' => 'Secret Person', 'anonymous' => true]);
        Donation::factory()->create(['campaign_id' => $this->campaign->id, 'mosque_id' => $this->mosque->id, 'amount' => 7000]);
        app(DonationLedger::class)->refresh($this->campaign->id);

        $response = $this->getJson('/campaigns/nouveau-toit/progress.json')
            ->assertOk()
            ->assertJsonPath('raised', 5000)
            ->assertJsonPath('pledged', 7000)
            ->assertJsonPath('goal', 1_000_000)
            ->assertJsonPath('donors_count', 2)
            ->assertJsonPath('percent', 0.5)
            ->assertJsonPath('currency', 'EUR')
            ->assertJsonPath('state', 'active')
            ->assertJsonCount(2, 'recent');

        $this->assertStringNotContainsString('amine@example.com', $response->getContent());
        $this->assertStringNotContainsString('Secret Person', $response->getContent());
        $this->assertStringContainsString('Amine', $response->getContent());
    }

    public function test_progress_json_is_public_only_when_the_campaign_page_is(): void
    {
        $this->completed(3000, ['donor_name' => 'Amine']);
        $this->mosque->forceFill(['verified_at' => null])->save();

        $this->getJson('/campaigns/nouveau-toit/progress.json')->assertNotFound();
        $this->get('/campaigns/nouveau-toit')->assertNotFound();

        $this->mosque->forceFill(['verified_at' => now()])->save();
        $this->campaign->forceFill(['status' => 'draft'])->save();
        $this->getJson('/campaigns/nouveau-toit/progress.json')->assertNotFound();
    }

    public function test_the_wall_lists_gifts_by_arrival_whatever_happens_later(): void
    {
        $first = $this->completed(1000, ['donor_name' => 'Premier']);
        $this->travel(5)->minutes();
        $this->completed(2000, ['donor_name' => 'Second']);
        $this->travel(5)->minutes();
        // Later bookkeeping on the first gift (a PayPal notification noted).
        $first->forceFill(['provider_payload' => ['events' => ['WH-1']]])->save();
        Cache::flush();

        $this->getJson('/campaigns/nouveau-toit/progress.json')
            ->assertJsonPath('recent.0.name', 'Second')
            ->assertJsonPath('recent.1.name', 'Premier');
    }

    public function test_campaigns_that_hide_names_never_show_them(): void
    {
        $this->campaign->forceFill(['show_donor_names' => false])->save();
        $this->completed(3000, ['donor_name' => 'Amine']);

        $this->assertStringNotContainsString('Amine', $this->getJson('/campaigns/nouveau-toit/progress.json')->getContent());
    }

    public function test_the_mosque_widget_lists_open_campaigns(): void
    {
        Campaign::factory()->create(['mosque_id' => $this->mosque->id, 'slug' => 'brouillon']);   // a draft

        $this->getJson("/mosques/{$this->mosque->slug}/campaigns.json")
            ->assertOk()
            ->assertJsonCount(1, 'campaigns')
            ->assertJsonPath('campaigns.0.slug', 'nouveau-toit')
            ->assertJsonPath('campaigns.0.goal', 1_000_000)
            ->assertJsonPath('campaigns.0.mosque.slug', $this->mosque->slug);

        $unverified = Mosque::factory()->create();
        Campaign::factory()->active()->create(['mosque_id' => $unverified->id]);
        $this->getJson("/mosques/{$unverified->slug}/campaigns.json")->assertOk()->assertJsonCount(0, 'campaigns');
    }

    public function test_the_explore_page_lists_open_campaigns_of_verified_mosques_only(): void
    {
        Campaign::factory()->create(['mosque_id' => $this->mosque->id, 'slug' => 'brouillon']);
        Campaign::factory()->active()->create(['mosque_id' => Mosque::factory()->create()->id, 'slug' => 'unverified']);
        Campaign::factory()->active()->create(['mosque_id' => $this->mosque->id, 'slug' => 'zakat-2026', 'kind' => 'zakat']);
        $ended = Campaign::factory()->active()->create(['mosque_id' => $this->mosque->id, 'slug' => 'fini']);
        $ended->forceFill(['status' => 'completed'])->save();

        $this->get('/campaigns')->assertOk()->assertInertia(fn (Assert $page) => $page
            ->component('campaigns/index')
            ->where('campaigns.total', 2));

        $this->get('/campaigns?kind=zakat')->assertInertia(fn (Assert $page) => $page
            ->where('campaigns.total', 1)
            ->where('campaigns.data.0.slug', 'zakat-2026'));

        $this->get('/campaigns?tab=ended')->assertInertia(fn (Assert $page) => $page
            ->where('campaigns.total', 1)
            ->where('campaigns.data.0.slug', 'fini'));

        // Anything unknown in the query string is ignored.
        $this->get('/campaigns?kind=<script>&tab=x&near=here&lat=abc')->assertOk();
    }

    public function test_campaigns_near_a_position(): void
    {
        $this->mosque->forceFill(['latitude' => 45.99, 'longitude' => 4.72])->save();
        $far = Mosque::factory()->verified()->at(43.3, 5.37)->create();
        Campaign::factory()->active()->create(['mosque_id' => $far->id, 'slug' => 'marseille']);

        $this->get('/campaigns?near=here&lat=45.76&lng=4.83')->assertInertia(fn (Assert $page) => $page
            ->where('filters.near', 'here')
            ->where('campaigns.total', 1)
            ->where('campaigns.data.0.slug', 'nouveau-toit'));
    }

    public function test_the_mosque_campaigns_page(): void
    {
        $this->get("/mosques/{$this->mosque->slug}/campaigns")->assertOk()->assertInertia(fn (Assert $page) => $page
            ->component('campaigns/mosque')
            ->where('open.0.slug', 'nouveau-toit'));
    }

    public function test_the_csv_export_is_safe_from_formulas_and_limited_to_the_mosque(): void
    {
        $this->completed(2500, ['donor_name' => '=HYPERLINK("http://evil.example","x")', 'message' => '+cmd|calc', 'reference' => 'ST-AAAA-BBBB']);
        $other = Campaign::factory()->active()->create();
        Donation::factory()->create(['campaign_id' => $other->id, 'mosque_id' => $other->mosque_id, 'reference' => 'ST-OTHE-RMSQ']);

        $response = $this->actingAs($this->manager)->get("/manage/{$this->mosque->slug}/donations/export.csv")->assertOk();
        $csv = $response->streamedContent();

        $this->assertStringContainsString('ST-AAAA-BBBB', $csv);
        $this->assertStringNotContainsString('ST-OTHE-RMSQ', $csv);
        $this->assertStringContainsString("'=HYPERLINK", $csv);
        $this->assertStringContainsString("'+cmd|calc", $csv);
        $this->assertStringContainsString('25.00', $csv);
        $this->assertSame("'-1", DonationCsv::cell('-1'));
        $this->assertSame("'@x", DonationCsv::cell('@x'));
        $this->assertSame('Amine', DonationCsv::cell('Amine'));
    }
}
