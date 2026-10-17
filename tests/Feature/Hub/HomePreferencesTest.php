<?php

namespace Tests\Feature\Hub;

use App\Http\Controllers\Hub\Support\HubPreferences;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Tests\TestCase;

/** PATCH /me/preferences/home: strict validation, only known keys, merged into users.preferences.home. */
class HomePreferencesTest extends TestCase
{
    use RefreshDatabase;

    public function test_guests_cannot_save_preferences(): void
    {
        $this->patchJson(route('me.preferences.home'), ['style' => 'dial'])->assertUnauthorized();
        $this->patch(route('me.preferences.home'), ['style' => 'dial'])->assertRedirect(route('login'));
    }

    public function test_a_user_saves_their_choices_merged_over_the_defaults(): void
    {
        $user = User::factory()->create();

        $this->actingAs($user)
            ->patchJson(route('me.preferences.home'), ['style' => 'dial', 'clock' => '12h', 'show_seconds' => false])
            ->assertOk()
            ->assertJson(['preferences' => [...HubPreferences::DEFAULTS, 'style' => 'dial', 'clock' => '12h', 'show_seconds' => false]]);

        // A later change keeps the earlier ones.
        $this->actingAs($user)
            ->patchJson(route('me.preferences.home'), ['adhan' => 'sound', 'adhan_id' => 'makkah', 'muted' => true])
            ->assertOk()
            ->assertJsonPath('preferences.style', 'dial')
            ->assertJsonPath('preferences.adhan', 'sound')
            ->assertJsonPath('preferences.adhan_id', 'makkah')
            ->assertJsonPath('preferences.muted', true);

        // jsonb keeps its own key order: compare key by key.
        $this->assertEquals(
            ['style' => 'dial', 'clock' => '12h', 'show_seconds' => false, 'adhan' => 'sound', 'adhan_id' => 'makkah', 'muted' => true],
            $user->fresh()->preferences['home'],
        );
    }

    public function test_unknown_keys_are_ignored_and_other_sections_are_kept(): void
    {
        $user = User::factory()->create();
        $user->forceFill(['preferences' => ['display' => ['theme' => 'night'], 'home' => ['style' => 'minimal']]])->save();

        $this->actingAs($user)
            ->patchJson(route('me.preferences.home'), ['compact' => true, 'is_admin' => true, 'evil' => '<script>'])
            ->assertOk();

        $user->refresh();
        $this->assertSame(['theme' => 'night'], $user->preferences['display']);
        $this->assertEquals(['style' => 'minimal', 'compact' => true], $user->preferences['home']);
        $this->assertFalse($user->is_admin);
    }

    public function test_values_are_validated_strictly(): void
    {
        $user = User::factory()->create();

        $this->actingAs($user)
            ->patchJson(route('me.preferences.home'), [
                'style' => 'neon',
                'clock' => '25h',
                'adhan' => 'loud',
                'show_iqama' => 'yes',
                'compact' => 1,
                'adhan_id' => '../../etc/passwd',
                'muted' => null,
            ])
            ->assertJsonValidationErrors(['style', 'clock', 'adhan', 'show_iqama', 'compact', 'adhan_id', 'muted']);

        $this->actingAs($user)
            ->patchJson(route('me.preferences.home'), ['adhan_id' => str_repeat('a', 129)])
            ->assertJsonValidationErrors(['adhan_id']);

        $this->assertNull($user->fresh()->preferences);
    }

    public function test_the_longest_catalog_ids_can_be_saved(): void
    {
        // GET /adhan/catalog.json names a dropped-in file "file:" + up to 60 characters.
        $id = 'file:'.str_repeat('a', 60);
        $user = User::factory()->create();

        $this->actingAs($user)
            ->patchJson(route('me.preferences.home'), ['adhan_id' => $id])
            ->assertOk()
            ->assertJsonPath('preferences.adhan_id', $id);
    }

    public function test_the_adhan_choice_can_be_cleared(): void
    {
        $user = User::factory()->create();
        $user->forceFill(['preferences' => ['home' => ['adhan_id' => 'makkah']]])->save();

        $this->actingAs($user)
            ->patchJson(route('me.preferences.home'), ['adhan_id' => null])
            ->assertOk()
            ->assertJsonPath('preferences.adhan_id', null);
    }

    public function test_stored_values_that_are_no_longer_valid_fall_back_to_the_defaults(): void
    {
        $user = User::factory()->create();
        $user->forceFill(['preferences' => ['home' => ['style' => 'retired', 'compact' => 'yes', 'show_hijri' => false, 'x' => 1]]])->save();

        $this->assertSame([...HubPreferences::DEFAULTS, 'show_hijri' => false], HubPreferences::of($user->fresh()));
    }

    public function test_preferences_that_hold_no_object_are_started_afresh(): void
    {
        // An empty PHP array is stored as "[]", and a JSON null may be left by
        // hand: jsonb_set cannot set a key in either (it used to fail with a 500).
        $empty = User::factory()->create();
        $empty->forceFill(['preferences' => []])->save();
        $this->assertSame('[]', DB::table('users')->where('id', $empty->id)->value('preferences'));

        $null = User::factory()->create();
        DB::table('users')->where('id', $null->id)->update(['preferences' => DB::raw("'null'::jsonb")]);

        foreach ([$empty, $null] as $user) {
            $this->actingAs($user)
                ->patchJson(route('me.preferences.home'), ['style' => 'timeline'])
                ->assertOk()
                ->assertJsonPath('preferences.style', 'timeline');

            $this->assertSame(['home' => ['style' => 'timeline']], $user->fresh()->preferences);
        }
    }

    public function test_an_inertia_request_is_sent_back(): void
    {
        $user = User::factory()->create();

        $this->actingAs($user)
            ->from('/')
            ->patch(route('me.preferences.home'), ['style' => 'arc'])
            ->assertRedirect('/');

        $this->assertSame('arc', $user->fresh()->preferences['home']['style']);
    }
}
