<?php

namespace Tests\Feature\Admin;

use App\Models\MosqueClaim;
use App\Models\User;
use App\Notifications\ClaimApproved;
use App\Notifications\ClaimRejected;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Notification;
use Inertia\Testing\AssertableInertia as Assert;
use Tests\TestCase;

class ClaimReviewTest extends TestCase
{
    use CreatesAdmins, RefreshDatabase;

    private User $admin;

    protected function setUp(): void
    {
        parent::setUp();
        $this->withoutVite(); // pages are checked as Inertia responses, not built assets
        $this->admin = $this->createAdmin();
    }

    public function test_the_queue_lists_pending_requests_by_default_and_filters_by_status(): void
    {
        $pending = MosqueClaim::factory()->count(2)->create();
        $approved = MosqueClaim::factory()->create(['status' => MosqueClaim::APPROVED]);

        $this->actingAs($this->admin)
            ->get('/admin/claims')
            ->assertOk()
            ->assertInertia(fn (Assert $page) => $page
                ->component('admin/claims/index')
                ->where('filters.status', 'pending')
                ->has('claims.data', 2)
                ->where('claims.data.0.id', $pending->first()->id)
                ->where('counts.pending', 2)
                ->where('counts.approved', 1)
                ->where('counts.all', 3)
                ->missing('claims.data.0.document_path'));

        $this->actingAs($this->admin)
            ->get('/admin/claims?status=approved')
            ->assertInertia(fn (Assert $page) => $page
                ->has('claims.data', 1)
                ->where('claims.data.0.id', $approved->id));

        // Unknown filter values fall back to the default.
        $this->actingAs($this->admin)
            ->get('/admin/claims?status=whatever')
            ->assertInertia(fn (Assert $page) => $page->where('filters.status', 'pending'));
    }

    public function test_the_queue_can_be_searched_by_claimant_or_mosque(): void
    {
        $match = MosqueClaim::factory()
            ->for(User::factory()->state(['name' => 'Yusuf Benali']))
            ->create();
        MosqueClaim::factory()->create();

        $this->actingAs($this->admin)
            ->get('/admin/claims?q=benali')
            ->assertInertia(fn (Assert $page) => $page
                ->has('claims.data', 1)
                ->where('claims.data.0.id', $match->id));

        $this->actingAs($this->admin)
            ->get('/admin/claims?q='.urlencode($match->mosque->name))
            ->assertInertia(fn (Assert $page) => $page->where('claims.data.0.id', $match->id));
    }

    public function test_the_claim_page_shows_the_claimant_the_mosque_and_its_managers(): void
    {
        $claim = MosqueClaim::factory()->create(['document_path' => 'claims/1/x.pdf']);
        $manager = User::factory()->create();
        $claim->mosque->managers()->attach($manager->id, ['role' => 'owner']);

        $this->actingAs($this->admin)
            ->get('/admin/claims/'.$claim->id)
            ->assertOk()
            ->assertInertia(fn (Assert $page) => $page
                ->component('admin/claims/show')
                ->where('claim.id', $claim->id)
                ->where('claim.phone', $claim->phone)
                ->where('claim.document_url', route('claims.document', $claim))
                ->missing('claim.document_path')
                ->where('claimant.email', $claim->user->email)
                ->where('mosque.slug', $claim->mosque->slug)
                ->has('managers', 1)
                ->where('managers.0.id', $manager->id));
    }

    public function test_approving_makes_the_claimant_owner_and_emails_them(): void
    {
        Notification::fake();
        $claimant = User::factory()->create(['locale' => 'ar']);
        $claim = MosqueClaim::factory()->for($claimant)->create();

        $this->actingAs($this->admin)
            ->post('/admin/claims/'.$claim->id.'/approve', ['note' => 'Bienvenue !'])
            ->assertRedirect(route('admin.claims.index'))
            ->assertInertiaFlash('toast.type', 'success');

        $claim->refresh();
        $this->assertSame(MosqueClaim::APPROVED, $claim->status);
        $this->assertSame($this->admin->id, $claim->reviewed_by);
        $this->assertNotNull($claim->reviewed_at);
        $this->assertSame('Bienvenue !', $claim->review_note);

        $this->assertDatabaseHas('mosque_managers', [
            'mosque_id' => $claim->mosque_id,
            'user_id' => $claimant->id,
            'role' => 'owner',
            'granted_by' => $this->admin->id,
        ]);
        $this->assertTrue($claimant->manages($claim->mosque));

        Notification::assertSentTo($claimant, ClaimApproved::class, fn (ClaimApproved $n) => $n->locale === 'ar');
        Notification::assertCount(1);
    }

    public function test_the_email_is_written_in_the_claimants_language(): void
    {
        $claimant = User::factory()->create(['locale' => 'fr']);
        $claim = MosqueClaim::factory()->for($claimant)->create();

        $this->actingAs($this->admin)->post('/admin/claims/'.$claim->id.'/approve')->assertRedirect();

        $messages = app('mail.manager')->mailer('array')->getSymfonyTransport()->messages();
        $this->assertCount(1, $messages);
        $email = $messages->first()->getOriginalMessage();
        $this->assertSame('Votre demande pour '.$claim->mosque->name.' est acceptée', $email->getSubject());
        $this->assertSame($claimant->email, $email->getTo()[0]->getAddress());
        $this->assertStringContainsString('Assalamou alaykoum', $email->getHtmlBody());
    }

    public function test_rejecting_requires_a_note(): void
    {
        Notification::fake();
        $claim = MosqueClaim::factory()->create();

        $this->actingAs($this->admin)
            ->post('/admin/claims/'.$claim->id.'/reject', ['note' => ''])
            ->assertSessionHasErrors('note');
        $this->actingAs($this->admin)
            ->post('/admin/claims/'.$claim->id.'/reject', ['note' => str_repeat('a', 1001)])
            ->assertSessionHasErrors('note');

        $this->assertSame(MosqueClaim::PENDING, $claim->fresh()->status);
        Notification::assertNothingSent();
    }

    public function test_rejecting_records_the_reason_and_emails_the_claimant(): void
    {
        Notification::fake();
        $claim = MosqueClaim::factory()->create();

        $this->actingAs($this->admin)
            ->post('/admin/claims/'.$claim->id.'/reject', ['note' => 'Merci de joindre les statuts de l\'association.'])
            ->assertRedirect(route('admin.claims.index'));

        $claim->refresh();
        $this->assertSame(MosqueClaim::REJECTED, $claim->status);
        $this->assertSame('Merci de joindre les statuts de l\'association.', $claim->review_note);
        $this->assertSame($this->admin->id, $claim->reviewed_by);
        $this->assertDatabaseCount('mosque_managers', 0);

        Notification::assertSentTo(
            $claim->user,
            ClaimRejected::class,
            fn (ClaimRejected $n) => $n->locale === config('app.locale'),
        );
    }

    public function test_a_decided_claim_cannot_be_decided_again(): void
    {
        Notification::fake();
        $claim = MosqueClaim::factory()->create(['status' => MosqueClaim::REJECTED, 'review_note' => 'Non']);

        $this->actingAs($this->admin)
            ->post('/admin/claims/'.$claim->id.'/approve')
            ->assertRedirect(route('admin.claims.show', $claim))
            ->assertInertiaFlash('toast.type', 'error');

        $this->assertSame(MosqueClaim::REJECTED, $claim->fresh()->status);
        $this->assertDatabaseCount('mosque_managers', 0);
        Notification::assertNothingSent();
    }

    public function test_approving_an_existing_editor_promotes_them_without_duplicates(): void
    {
        Notification::fake();
        $claim = MosqueClaim::factory()->create();
        $claim->mosque->managers()->attach($claim->user_id, ['role' => 'editor']);

        $this->actingAs($this->admin)->post('/admin/claims/'.$claim->id.'/approve')->assertRedirect();

        $this->assertDatabaseCount('mosque_managers', 1);
        $this->assertDatabaseHas('mosque_managers', ['user_id' => $claim->user_id, 'role' => 'owner']);
    }

    public function test_unknown_claims_are_not_found(): void
    {
        $this->actingAs($this->admin)->get('/admin/claims/999999')->assertNotFound();
        $this->actingAs($this->admin)->post('/admin/claims/999999/approve')->assertNotFound();
    }
}
