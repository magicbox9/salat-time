<?php

namespace Tests\Feature\Fundraising;

use App\Models\Campaign;
use App\Models\Donation;
use App\Models\Mosque;
use App\Models\User;
use App\Notifications\CampaignApproved;
use App\Notifications\CampaignRejected;
use App\Notifications\CampaignSubmitted;
use App\Services\Fundraising\ReviewVersion;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Notification;
use Illuminate\Support\Facades\Storage;
use Inertia\Testing\AssertableInertia as Assert;
use Tests\TestCase;

class CampaignManagementTest extends TestCase
{
    use FundraisingFixtures, RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        $this->setUpFundraising();
        Notification::fake();
        Storage::fake('public');
    }

    /** @return array<string, mixed> */
    private function form(array $overrides = []): array
    {
        return [
            'kind' => 'iftar',
            'title' => 'Iftars du Ramadan',
            'summary' => 'Offrir un repas chaque soir aux jeûneurs du quartier.',
            'story' => "## Notre projet\n\nChaque soir, la mosquée accueille 200 personnes pour l'iftar.",
            'goal' => 8000,
            'starts_on' => '',
            'ends_on' => now()->addMonth()->format('Y-m-d'),
            'allow_paypal' => true,
            'allow_bank' => true,
            'show_donor_names' => true,
            ...$overrides,
        ];
    }

    private function base(): string
    {
        return "/manage/{$this->mosque->slug}/campaigns";
    }

    public function test_managers_open_every_fundraising_page(): void
    {
        foreach (['/campaigns', '/campaigns/create', '/campaigns/nouveau-toit', '/campaigns/nouveau-toit/edit', '/payouts', '/donations'] as $page) {
            $this->actingAs($this->manager)->get("/manage/{$this->mosque->slug}{$page}")->assertOk();
        }
    }

    public function test_strangers_are_refused_everywhere(): void
    {
        $stranger = User::factory()->create();
        foreach (['/campaigns', '/campaigns/create', '/campaigns/nouveau-toit', '/payouts', '/donations', '/donations/export.csv'] as $page) {
            $this->actingAs($stranger)->get("/manage/{$this->mosque->slug}{$page}")->assertForbidden();
        }
        $this->actingAs($stranger)->post($this->base(), $this->form())->assertForbidden();
        $this->actingAs($stranger)->post($this->base().'/nouveau-toit/close')->assertForbidden();
        $this->assertSame('active', $this->campaign->fresh()->status);
    }

    public function test_a_manager_writes_a_draft_with_a_cover(): void
    {
        $this->actingAs($this->manager)
            ->post($this->base(), $this->form(['cover' => UploadedFile::fake()->image('cover.jpg', 1200, 600)]))
            ->assertRedirect();

        $campaign = Campaign::query()->where('title', 'Iftars du Ramadan')->firstOrFail();
        $this->assertSame('draft', $campaign->status);
        $this->assertSame('iftars-du-ramadan', $campaign->slug);
        $this->assertSame(800_000, $campaign->goal_amount);
        $this->assertSame($this->mosque->id, $campaign->mosque_id);
        $this->assertSame($this->manager->id, $campaign->created_by);
        $this->assertNotNull($campaign->cover_path);
        Storage::disk('public')->assertExists($campaign->cover_path);
        $this->assertNotNull($campaign->ends_at);

        // Drafts are not public.
        $this->asGuest()->get('/campaigns/iftars-du-ramadan')->assertNotFound();
        $this->get('/campaigns/iftars-du-ramadan/progress.json')->assertNotFound();
        $this->actingAs($this->manager)->get('/campaigns/iftars-du-ramadan')->assertOk();
    }

    public function test_status_and_totals_cannot_be_mass_assigned(): void
    {
        $this->actingAs($this->manager)->post($this->base(), $this->form([
            'status' => 'active', 'raised_amount' => 999999, 'mosque_id' => Mosque::factory()->create()->id, 'slug' => 'hijack',
        ]))->assertRedirect();

        $campaign = Campaign::query()->where('title', 'Iftars du Ramadan')->firstOrFail();
        $this->assertSame('draft', $campaign->status);
        $this->assertSame(0, $campaign->raised_amount);
        $this->assertSame($this->mosque->id, $campaign->mosque_id);
        $this->assertNotSame('hijack', $campaign->slug);
    }

    public function test_the_form_is_validated(): void
    {
        $this->actingAs($this->manager)->post($this->base(), $this->form([
            'kind' => 'casino', 'title' => '', 'goal' => 5, 'ends_on' => '2020-01-01',
        ]))->assertSessionHasErrors(['kind', 'title', 'goal', 'ends_on']);
        $this->assertSame(1, Campaign::query()->count());
    }

    public function test_only_verified_ways_of_giving_can_be_allowed(): void
    {
        $this->paypalPayout->forceFill(['verified_at' => null])->save();

        $this->actingAs($this->manager)->post($this->base(), $this->form(['allow_paypal' => true]))
            ->assertSessionHasErrors('allow_paypal');
        $this->actingAs($this->manager)->post($this->base(), $this->form(['allow_paypal' => false]))
            ->assertSessionHasNoErrors();
    }

    public function test_submission_is_blocked_for_an_unverified_mosque(): void
    {
        $draft = $this->draft();
        $this->mosque->forceFill(['verified_at' => null])->save();

        $this->actingAs($this->manager)->post($this->base()."/{$draft->slug}/submit")->assertRedirect();

        $this->assertSame('draft', $draft->fresh()->status);
        Notification::assertNothingSent();
    }

    public function test_submission_is_blocked_without_a_verified_payout(): void
    {
        $draft = $this->draft();
        $this->paypalPayout->forceFill(['verified_at' => null])->save();
        $this->bankPayout->forceFill(['verified_at' => null])->save();

        $this->actingAs($this->manager)->post($this->base()."/{$draft->slug}/submit")->assertRedirect();
        $this->assertSame('draft', $draft->fresh()->status);

        $this->actingAs($this->manager)->get($this->base())
            ->assertInertia(fn (Assert $page) => $page
                ->component('fundraising/index')
                ->where('problems', ['no_verified_payout']));
    }

    public function test_submission_then_admin_approval_makes_it_public(): void
    {
        $admin = $this->admin();
        $draft = $this->draft();

        $this->actingAs($this->manager)->post($this->base()."/{$draft->slug}/submit")->assertRedirect();
        $this->assertSame('pending', $draft->fresh()->status);
        Notification::assertSentTo($admin, CampaignSubmitted::class);
        $this->asGuest()->get("/campaigns/{$draft->slug}")->assertNotFound();

        // Managers cannot approve their own campaign.
        $this->actingAs($this->manager)->post("/admin/fundraising/campaigns/{$draft->slug}/approve")->assertForbidden();

        $this->actingAs($admin)->post($this->approveUrl($draft->fresh()), ['note' => 'Qu’Allah facilite.'])->assertRedirect();
        $draft->refresh();
        $this->assertSame('active', $draft->status);
        $this->assertSame($admin->id, $draft->reviewed_by);
        $this->assertNotNull($draft->starts_at);
        Notification::assertSentTo($this->manager, CampaignApproved::class);

        $this->asGuest()->get("/campaigns/{$draft->slug}")->assertOk();
        $this->get('/campaigns')->assertInertia(fn (Assert $page) => $page
            ->component('campaigns/index')
            ->where('campaigns.total', 2));

        // A second approval changes nothing.
        $this->actingAs($admin)->post($this->approveUrl($draft->fresh()))->assertRedirect();
        Notification::assertSentToTimes($this->manager, CampaignApproved::class, 1);
    }

    public function test_admin_rejection_needs_a_reason_and_tells_the_managers(): void
    {
        $admin = $this->admin();
        $draft = $this->draft();
        $draft->forceFill(['status' => 'pending'])->save();

        $this->actingAs($admin)->post("/admin/fundraising/campaigns/{$draft->slug}/reject", ['note' => ''])->assertSessionHasErrors('note');
        $this->assertSame('pending', $draft->fresh()->status);

        $this->actingAs($admin)->post("/admin/fundraising/campaigns/{$draft->slug}/reject", ['note' => 'Merci de préciser le budget.'])->assertRedirect();
        $draft->refresh();
        $this->assertSame('rejected', $draft->status);
        $this->assertSame('Merci de préciser le budget.', $draft->review_note);
        Notification::assertSentTo($this->manager, CampaignRejected::class);

        // The manager edits it and submits it again.
        $this->actingAs($this->manager)->put($this->base()."/{$draft->slug}", $this->form(['title' => 'Iftars 2027']))->assertRedirect();
        $this->actingAs($this->manager)->post($this->base()."/{$draft->slug}/submit")->assertRedirect();
        $this->assertSame('pending', $draft->fresh()->status);
    }

    public function test_approval_is_refused_when_the_mosque_lost_its_verification(): void
    {
        $admin = $this->admin();
        $draft = $this->draft();
        $draft->forceFill(['status' => 'pending'])->save();
        $this->mosque->forceFill(['verified_at' => null])->save();

        $this->actingAs($admin)->post($this->approveUrl($draft->fresh()))->assertRedirect();
        $this->assertSame('pending', $draft->fresh()->status);
    }

    public function test_the_admin_approves_only_the_version_they_reviewed(): void
    {
        $admin = $this->admin();
        $draft = $this->draft();
        $draft->forceFill(['status' => 'pending'])->save();

        $this->actingAs($admin)->get("/admin/fundraising/campaigns/{$draft->slug}")->assertOk()
            ->assertInertia(fn (Assert $page) => $page->where('campaign.version', ReviewVersion::campaign($draft->fresh())));
        $reviewed = $this->approveUrl($draft->fresh());

        // The manager rewrites the story while the admin is reading the old one.
        $this->actingAs($this->manager)->put($this->base()."/{$draft->slug}", $this->form([
            'story' => 'Une tout autre histoire que celle relue par l’équipe, avec un autre projet.',
        ]))->assertRedirect();

        $this->actingAs($admin)->post($reviewed)->assertRedirect()
            ->assertInertiaFlash('toast.message', ui('fundraising.admin_campaign_changed'));
        $this->assertSame('pending', $draft->fresh()->status);

        // Without a version, nothing is approved either.
        $this->actingAs($admin)->post("/admin/fundraising/campaigns/{$draft->slug}/approve")->assertRedirect();
        $this->assertSame('pending', $draft->fresh()->status);
        Notification::assertNotSentTo($this->manager, CampaignApproved::class);

        // Once the new text is reviewed, it can be approved.
        $this->actingAs($admin)->post($this->approveUrl($draft->fresh()))->assertRedirect();
        $this->assertSame('active', $draft->fresh()->status);
    }

    public function test_review_notes_must_be_plain_text(): void
    {
        $admin = $this->admin();
        $draft = $this->draft();
        $draft->forceFill(['status' => 'pending'])->save();

        $this->actingAs($admin)->post("/admin/fundraising/campaigns/{$draft->slug}/reject", ['note' => "Budget\0 manquant"])
            ->assertSessionHasErrors('note');
        $this->actingAs($admin)->post($this->approveUrl($draft->fresh()), ['note' => "Bien\0 reçu"])->assertSessionHasErrors('note');
        $this->assertSame('pending', $draft->fresh()->status);
    }

    public function test_a_manager_cannot_reach_another_mosques_campaign_through_their_own(): void
    {
        $otherMosque = Mosque::factory()->verified()->create();
        $other = Campaign::factory()->active()->create(['mosque_id' => $otherMosque->id]);

        foreach (['', '/edit'] as $page) {
            $this->actingAs($this->manager)->get($this->base()."/{$other->slug}{$page}")->assertNotFound();
        }
        $this->actingAs($this->manager)->put($this->base()."/{$other->slug}", $this->form())->assertNotFound();
        $this->actingAs($this->manager)->post($this->base()."/{$other->slug}/close")->assertNotFound();
        $this->actingAs($this->manager)->post($this->base()."/{$other->slug}/updates", ['title' => 'Piratage', 'body' => 'Rien à voir.'])->assertNotFound();
        $this->actingAs($this->manager)->delete($this->base()."/{$other->slug}")->assertNotFound();

        $this->assertSame('active', $other->fresh()->status);
        $this->assertDatabaseCount('campaign_updates', 0);
    }

    public function test_a_campaign_can_be_saved_after_its_paypal_account_lost_its_verification(): void
    {
        // The form sends a disabled (unverified) way of giving as unticked.
        $this->paypalPayout->forceFill(['verified_at' => null])->save();

        $this->actingAs($this->manager)->put($this->base().'/nouveau-toit', $this->form(['allow_paypal' => false]))
            ->assertSessionHasNoErrors()->assertRedirect();
        $this->assertFalse($this->campaign->fresh()->allow_paypal);
    }

    public function test_abandoned_paypal_windows_are_not_donations(): void
    {
        $draft = $this->draft();
        Donation::factory()->create([
            'campaign_id' => $draft->id, 'mosque_id' => $this->mosque->id, 'method' => 'paypal', 'reference' => 'ST-AAAA-BBBB',
        ])->forceFill(['status' => 'cancelled'])->save();

        $this->actingAs($this->manager)->get($this->base()."/{$draft->slug}")
            ->assertInertia(fn (Assert $page) => $page->where('donations', []));

        $this->actingAs($this->manager)->delete($this->base()."/{$draft->slug}")->assertRedirect();
        $this->assertSoftDeleted($draft);
    }

    private function approveUrl(Campaign $campaign): string
    {
        return "/admin/fundraising/campaigns/{$campaign->slug}/approve?version=".ReviewVersion::campaign($campaign);
    }

    public function test_title_and_kind_are_fixed_once_approved(): void
    {
        $this->actingAs($this->manager)->put($this->base().'/nouveau-toit', $this->form([
            'title' => 'Autre chose', 'kind' => 'zakat', 'summary' => 'Un nouveau résumé du projet de toiture.',
        ]))->assertRedirect();

        $campaign = $this->campaign->fresh();
        $this->assertSame('Nouveau toit', $campaign->title);
        $this->assertSame('building', $campaign->kind);
        $this->assertSame('Un nouveau résumé du projet de toiture.', $campaign->summary);
    }

    public function test_closing_an_open_campaign(): void
    {
        $this->actingAs($this->manager)->post($this->base().'/nouveau-toit/close')->assertRedirect();
        $this->assertSame('closed', $this->campaign->fresh()->status);

        // Closed campaigns stay visible, read-only.
        $this->get('/campaigns/nouveau-toit')->assertOk()->assertInertia(fn (Assert $page) => $page
            ->where('methods.paypal', false)
            ->where('methods.bank', false));
    }

    public function test_updates_are_published_and_deleted(): void
    {
        $this->actingAs($this->manager)->post($this->base().'/nouveau-toit/updates', [
            'title' => 'La charpente est posée', 'body' => 'Merci à tous, *alhamdulillah*.',
        ])->assertRedirect();

        $update = $this->campaign->updates()->firstOrFail();
        $this->get('/campaigns/nouveau-toit')->assertInertia(fn (Assert $page) => $page
            ->where('updates.0.title', 'La charpente est posée')
            ->where('updates.0.body_html', "<p>Merci à tous, <em>alhamdulillah</em>.</p>\n"));

        $other = Campaign::factory()->active()->create();
        $this->actingAs($this->manager)->delete($this->base()."/{$other->slug}/updates/{$update->id}")->assertNotFound();
        $this->actingAs($this->manager)->delete($this->base()."/nouveau-toit/updates/{$update->id}")->assertRedirect();
        $this->assertDatabaseCount('campaign_updates', 0);
    }

    public function test_a_campaign_with_donations_cannot_be_deleted(): void
    {
        $draft = $this->draft();
        $this->actingAs($this->manager)->delete($this->base()."/{$draft->slug}")->assertRedirect();
        $this->assertSoftDeleted($draft);

        $this->actingAs($this->manager)->delete($this->base().'/nouveau-toit')->assertRedirect();
        $this->assertNotSoftDeleted($this->campaign);
    }

    private function draft(): Campaign
    {
        return Campaign::factory()->create([
            'mosque_id' => $this->mosque->id,
            'title' => 'Cours du samedi',
            'slug' => 'cours-du-samedi',
            'allow_paypal' => true,
            'allow_bank' => true,
            'ends_at' => now()->addMonths(2),
        ]);
    }
}
