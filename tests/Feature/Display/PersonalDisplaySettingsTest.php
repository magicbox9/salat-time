<?php

namespace Tests\Feature\Display;

use App\Models\User;
use App\Support\ChosenMosque;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Inertia\Testing\AssertableInertia as Assert;
use Tests\TestCase;

class PersonalDisplaySettingsTest extends TestCase
{
    use DisplayFixtures, RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        $this->withoutVite();
    }

    public function test_guests_open_the_page_but_save_in_their_browser(): void
    {
        $this->get('/display/settings')->assertOk()->assertInertia(fn (Assert $page) => $page
            ->component('display/personal-settings')
            ->where('signedIn', false)
            ->where('settings', null)
            ->where('mosque', null)
            ->has('options.defaults.theme'));

        $this->put('/display/settings', ['theme' => 'minimal'])->assertRedirect('/login');
    }

    public function test_users_save_only_known_keys_and_keep_their_other_preferences(): void
    {
        $user = User::factory()->create();
        DB::table('users')->where('id', $user->id)->update(['preferences' => json_encode(['home' => ['style' => 'arc']])]);

        $this->actingAs($user)
            ->putJson('/display/settings', [
                'theme' => 'night_sky',
                'muted' => true,
                'adhan_mode' => 'sound',
                'is_admin' => true,
                'email' => 'x@example.com',
            ])
            ->assertOk()
            ->assertJsonPath('settings.theme', 'night_sky')
            ->assertJsonPath('settings.muted', true);

        $user->refresh();
        $this->assertSame('arc', $user->preferences['home']['style']);
        $this->assertSame('night_sky', $user->preferences['display']['theme']);
        $this->assertTrue($user->preferences['display']['muted']);
        $this->assertArrayNotHasKey('is_admin', $user->preferences['display']);
        $this->assertArrayNotHasKey('email', $user->preferences['display']);
        $this->assertFalse($user->is_admin);
        $this->assertNotSame('x@example.com', $user->email);

        // A second change merges into the first.
        $this->actingAs($user)->putJson('/display/settings', ['volume' => 30])->assertOk();
        $user->refresh();
        $this->assertSame('night_sky', $user->preferences['display']['theme']);
        $this->assertSame(30, $user->preferences['display']['volume']);
    }

    public function test_invalid_personal_values_are_refused(): void
    {
        $user = User::factory()->create();

        $this->actingAs($user)
            ->putJson('/display/settings', ['theme' => 'neon', 'volume' => 150, 'muted' => 'maybe'])
            ->assertUnprocessable()
            ->assertJsonValidationErrors(['theme', 'volume', 'muted']);

        $this->assertNull($user->fresh()->preferences);
    }

    public function test_the_personal_screen_shows_the_visitors_own_mosque(): void
    {
        $mosque = $this->mosque();
        $user = User::factory()->create();
        $user->favoriteMosques()->attach($mosque, ['is_primary' => true]);
        $this->actingAs($user)->putJson('/display/settings', ['theme' => 'minimal'])->assertOk();

        $this->actingAs($user)->get('/display')->assertOk()->assertInertia(fn (Assert $page) => $page
            ->component('display/screen')
            ->where('mode', 'personal')
            ->where('payload.mosque.slug', $mosque->slug)
            ->where('personal.theme', 'minimal')
            ->where('settingsUrl', '/display/settings'));
    }

    public function test_a_guest_screen_follows_the_chosen_mosque_cookie(): void
    {
        $mosque = $this->mosque();

        $this->withCookie(ChosenMosque::COOKIE, $mosque->slug)->get('/display')
            ->assertOk()
            ->assertInertia(fn (Assert $page) => $page
                ->where('payload.mosque.slug', $mosque->slug)
                ->where('personal', null)
                ->where('signedIn', false));
    }

    public function test_without_a_chosen_mosque_the_screen_invites_to_choose_one(): void
    {
        $this->get('/display')->assertOk()->assertInertia(fn (Assert $page) => $page
            ->component('display/screen')
            ->where('payload', null));
    }
}
