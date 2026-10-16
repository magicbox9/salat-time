<?php

namespace Tests\Feature\Claims;

use App\Models\MosqueClaim;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Inertia\Testing\AssertableInertia as Assert;
use Tests\TestCase;

class MyClaimsTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        $this->withoutVite(); // pages are checked as Inertia responses, not built assets
    }

    public function test_guests_are_sent_to_the_login_page(): void
    {
        $this->get('/me/claims')->assertRedirect(route('login'));
    }

    public function test_a_user_sees_only_their_own_requests(): void
    {
        $user = User::factory()->create();
        $reviewer = User::factory()->create();
        MosqueClaim::factory()->for($user)->create(['created_at' => now()->subDays(3)]);
        MosqueClaim::factory()->for($user)->create([
            'status' => MosqueClaim::REJECTED,
            'review_note' => 'Merci de joindre les statuts.',
            'reviewed_by' => $reviewer->id,
            'reviewed_at' => now(),
        ]);
        MosqueClaim::factory()->create(); // someone else's

        $this->actingAs($user)
            ->get('/me/claims')
            ->assertOk()
            ->assertInertia(fn (Assert $page) => $page
                ->component('me/claims')
                ->has('claims', 2)
                ->where('claims.0.status', MosqueClaim::REJECTED)
                ->where('claims.0.review_note', 'Merci de joindre les statuts.')
                ->where('claims.1.status', MosqueClaim::PENDING)
                ->has('claims.0.mosque.slug')
                ->missing('claims.0.document_path')
                ->missing('claims.0.phone'));
    }
}
