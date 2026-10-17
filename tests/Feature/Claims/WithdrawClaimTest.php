<?php

namespace Tests\Feature\Claims;

use App\Models\Mosque;
use App\Models\MosqueClaim;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Storage;
use Tests\TestCase;

/** A claimant withdraws a request that is still waiting for review. */
class WithdrawClaimTest extends TestCase
{
    use RefreshDatabase;

    public function test_the_claimant_withdraws_a_pending_request_and_its_document(): void
    {
        Storage::fake('local');
        $user = User::factory()->create();
        $claim = MosqueClaim::factory()->for(Mosque::factory())->for($user)->create(['status' => MosqueClaim::PENDING]);
        Storage::disk('local')->put("claims/{$claim->id}/proof.pdf", 'pdf');
        $claim->forceFill(['document_path' => "claims/{$claim->id}/proof.pdf"])->save();

        $this->actingAs($user)
            ->delete(route('claims.withdraw', $claim))
            ->assertRedirect(route('claims.mine'));

        $this->assertModelMissing($claim);
        Storage::disk('local')->assertMissing("claims/{$claim->id}/proof.pdf");
    }

    public function test_a_new_request_can_be_sent_after_withdrawing(): void
    {
        $user = User::factory()->create();
        $mosque = Mosque::factory()->create();
        $claim = MosqueClaim::factory()->for($mosque)->for($user)->create(['status' => MosqueClaim::PENDING]);

        $this->actingAs($user)->delete(route('claims.withdraw', $claim));

        $this->actingAs($user)->get(route('claims.create', $mosque))->assertOk();
    }

    public function test_someone_else_cannot_withdraw_a_request(): void
    {
        $claim = MosqueClaim::factory()->for(Mosque::factory())->create(['status' => MosqueClaim::PENDING]);
        $admin = User::factory()->create(['is_admin' => true]);

        $this->actingAs(User::factory()->create())->delete(route('claims.withdraw', $claim))->assertForbidden();
        // Admins review requests; withdrawing is the claimant's own choice.
        $this->actingAs($admin)->delete(route('claims.withdraw', $claim))->assertForbidden();
        $this->assertModelExists($claim);
    }

    public function test_a_reviewed_request_cannot_be_withdrawn(): void
    {
        $user = User::factory()->create();
        foreach ([MosqueClaim::APPROVED, MosqueClaim::REJECTED] as $status) {
            $claim = MosqueClaim::factory()->for(Mosque::factory())->for($user)->create(['status' => $status]);

            $this->actingAs($user)->delete(route('claims.withdraw', $claim))->assertForbidden();
            $this->assertModelExists($claim);
        }
    }

    public function test_guests_are_sent_to_sign_in(): void
    {
        $claim = MosqueClaim::factory()->for(Mosque::factory())->create(['status' => MosqueClaim::PENDING]);

        $this->delete(route('claims.withdraw', $claim))->assertRedirect(route('login'));
        $this->assertModelExists($claim);
    }

    public function test_only_numeric_ids_match(): void
    {
        $this->actingAs(User::factory()->create())->delete('/me/claims/abc')->assertNotFound();
    }
}
