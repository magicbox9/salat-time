<?php

namespace Tests\Feature\Claims;

use App\Models\MosqueClaim;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Storage;
use Tests\TestCase;

class ClaimDocumentTest extends TestCase
{
    use RefreshDatabase;

    private MosqueClaim $claim;

    protected function setUp(): void
    {
        parent::setUp();
        $this->withoutVite(); // pages are checked as Inertia responses, not built assets
        Storage::fake('local');

        $this->claim = MosqueClaim::factory()->create();
        $path = 'claims/'.$this->claim->id.'/a1b2c3.pdf';
        Storage::disk('local')->put($path, '%PDF-1.4 statuts');
        $this->claim->forceFill(['document_path' => $path])->save();
    }

    public function test_an_admin_can_download_the_document(): void
    {
        $admin = User::factory()->create();
        $admin->forceFill(['is_admin' => true])->save();

        $response = $this->actingAs($admin)->get(route('claims.document', $this->claim));

        $response->assertOk();
        $response->assertDownload('claim-'.$this->claim->id.'-document.pdf');
        $response->assertHeader('X-Content-Type-Options', 'nosniff');
        $this->assertSame('%PDF-1.4 statuts', $response->streamedContent());
    }

    public function test_the_claimant_can_download_their_own_document(): void
    {
        $this->actingAs($this->claim->user)
            ->get(route('claims.document', $this->claim))
            ->assertOk()
            ->assertDownload();
    }

    public function test_anyone_else_is_refused(): void
    {
        $stranger = User::factory()->create();
        $manager = User::factory()->create();
        $this->claim->mosque->managers()->attach($manager->id, ['role' => 'owner']);

        $this->actingAs($stranger)->get(route('claims.document', $this->claim))->assertForbidden();
        $this->actingAs($manager)->get(route('claims.document', $this->claim))->assertForbidden();
    }

    public function test_guests_are_sent_to_the_login_page(): void
    {
        $this->get(route('claims.document', $this->claim))->assertRedirect(route('login'));
    }

    public function test_a_claim_without_document_is_not_found(): void
    {
        $other = MosqueClaim::factory()->create();

        $this->actingAs($other->user)->get(route('claims.document', $other))->assertNotFound();
    }

    public function test_the_private_file_is_not_reachable_from_the_public_storage_url(): void
    {
        // The private disk is only served through signed URLs, which the app never generates.
        $response = $this->get('/storage/'.$this->claim->document_path);

        $this->assertContains($response->status(), [403, 404]);
        $response->assertDontSee('%PDF-1.4 statuts');
    }
}
