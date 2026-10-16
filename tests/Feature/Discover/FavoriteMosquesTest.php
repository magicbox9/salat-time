<?php

namespace Tests\Feature\Discover;

use App\Http\Controllers\Discover\FavoriteMosqueController;
use App\Models\Mosque;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Tests\TestCase;

class FavoriteMosquesTest extends TestCase
{
    use RefreshDatabase;

    public function test_guests_cannot_save_mosques(): void
    {
        $mosque = Mosque::factory()->create();

        $this->post("/mosques/{$mosque->slug}/favorite")->assertRedirect(route('login'));
        $this->postJson("/mosques/{$mosque->slug}/favorite")->assertUnauthorized();
        $this->postJson("/mosques/{$mosque->slug}/primary")->assertUnauthorized();
        $this->deleteJson("/mosques/{$mosque->slug}/favorite")->assertUnauthorized();

        $this->assertDatabaseCount('favorite_mosques', 0);
    }

    public function test_a_user_can_save_and_remove_a_mosque(): void
    {
        $user = User::factory()->create();
        $mosque = Mosque::factory()->create();

        $this->actingAs($user)
            ->postJson("/mosques/{$mosque->slug}/favorite")
            ->assertOk()
            ->assertJson(['slug' => $mosque->slug, 'is_favorite' => true, 'is_primary' => false]);
        $this->assertDatabaseHas('favorite_mosques', ['user_id' => $user->id, 'mosque_id' => $mosque->id, 'is_primary' => false]);

        $this->actingAs($user)
            ->deleteJson("/mosques/{$mosque->slug}/favorite")
            ->assertOk()
            ->assertJson(['is_favorite' => false, 'is_primary' => false]);
        $this->assertDatabaseCount('favorite_mosques', 0);
    }

    public function test_saving_twice_keeps_a_single_row(): void
    {
        $user = User::factory()->create();
        $mosque = Mosque::factory()->create();

        $this->actingAs($user)->postJson("/mosques/{$mosque->slug}/favorite")->assertOk();
        $this->actingAs($user)->postJson("/mosques/{$mosque->slug}/favorite")->assertOk()->assertJson(['is_favorite' => true]);

        $this->assertSame(1, DB::table('favorite_mosques')->where('user_id', $user->id)->count());
    }

    public function test_only_one_mosque_can_be_the_users_own(): void
    {
        $user = User::factory()->create();
        [$first, $second] = Mosque::factory()->count(2)->create();

        // Setting a primary mosque saves it when needed.
        $this->actingAs($user)->postJson("/mosques/{$first->slug}/primary")
            ->assertOk()
            ->assertJson(['is_favorite' => true, 'is_primary' => true]);
        $this->actingAs($user)->postJson("/mosques/{$second->slug}/favorite")->assertOk();
        $this->actingAs($user)->postJson("/mosques/{$second->slug}/primary")->assertOk()->assertJson(['is_primary' => true]);

        $this->assertSame([$second->id], DB::table('favorite_mosques')->where('user_id', $user->id)->where('is_primary', true)->pluck('mosque_id')->all());
        $this->assertSame(2, DB::table('favorite_mosques')->where('user_id', $user->id)->count());

        // Unsetting keeps the mosque saved.
        $this->actingAs($user)->deleteJson("/mosques/{$second->slug}/primary")
            ->assertOk()
            ->assertJson(['is_favorite' => true, 'is_primary' => false]);
        $this->assertSame(0, DB::table('favorite_mosques')->where('user_id', $user->id)->where('is_primary', true)->count());
    }

    public function test_removing_the_users_own_mosque_clears_it(): void
    {
        $user = User::factory()->create();
        $mosque = Mosque::factory()->create();
        $user->favoriteMosques()->attach($mosque->id, ['is_primary' => true]);

        $this->actingAs($user)->deleteJson("/mosques/{$mosque->slug}/favorite")->assertOk();

        $this->assertDatabaseCount('favorite_mosques', 0);
    }

    public function test_changes_only_touch_the_signed_in_users_list(): void
    {
        $user = User::factory()->create();
        $other = User::factory()->create();
        $mosque = Mosque::factory()->create();
        $other->favoriteMosques()->attach($mosque->id, ['is_primary' => true]);

        $this->actingAs($user)->postJson("/mosques/{$mosque->slug}/primary", ['user_id' => $other->id])->assertOk();
        $this->actingAs($user)->deleteJson("/mosques/{$mosque->slug}/favorite", ['user_id' => $other->id])->assertOk();

        $this->assertDatabaseHas('favorite_mosques', ['user_id' => $other->id, 'mosque_id' => $mosque->id, 'is_primary' => true]);
        $this->assertDatabaseMissing('favorite_mosques', ['user_id' => $user->id]);
    }

    public function test_a_page_form_is_redirected_back_with_a_toast(): void
    {
        $user = User::factory()->create();
        $mosque = Mosque::factory()->create();

        $this->actingAs($user)
            ->from('/me/mosques')
            ->post("/mosques/{$mosque->slug}/primary")
            ->assertRedirect('/me/mosques')
            ->assertInertiaFlash('toast.type', 'success');
    }

    public function test_unknown_mosques_and_full_lists_are_refused(): void
    {
        $user = User::factory()->create();

        $this->actingAs($user)->postJson('/mosques/no-such-mosque/favorite')->assertNotFound();

        $mosques = Mosque::factory()->count(FavoriteMosqueController::MAX)->create();
        $user->favoriteMosques()->attach($mosques->modelKeys());
        $extra = Mosque::factory()->create();

        $this->actingAs($user)->postJson("/mosques/{$extra->slug}/favorite")->assertJsonValidationErrors('mosque');
        $this->actingAs($user)->postJson("/mosques/{$extra->slug}/primary")->assertJsonValidationErrors('mosque');
        $this->assertDatabaseMissing('favorite_mosques', ['user_id' => $user->id, 'mosque_id' => $extra->id]);
    }
}
