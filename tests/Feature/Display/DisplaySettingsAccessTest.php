<?php

namespace Tests\Feature\Display;

use App\Models\Mosque;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Inertia\Testing\AssertableInertia as Assert;
use Tests\TestCase;

class DisplaySettingsAccessTest extends TestCase
{
    use DisplayFixtures, RefreshDatabase;

    private Mosque $mosque;

    protected function setUp(): void
    {
        parent::setUp();
        $this->withoutVite();
        $this->mosque = $this->mosque();
    }

    /** @return list<array{string, string, array<string, mixed>}> */
    private function writes(): array
    {
        $base = "/manage/{$this->mosque->slug}/display";

        return [
            ['put', $base, ['theme' => 'minimal']],
            ['post', "$base/messages", ['body' => 'Hello']],
            ['put', "$base/messages/order", ['ids' => [1]]],
            ['delete', "$base/background", []],
            ['delete', "$base/adhan", []],
        ];
    }

    public function test_guests_are_sent_to_the_login_page(): void
    {
        $this->get("/manage/{$this->mosque->slug}/display")->assertRedirect('/login');

        foreach ($this->writes() as [$method, $url, $data]) {
            $this->{$method}($url, $data)->assertRedirect('/login');
        }
        $this->assertDatabaseCount('mosque_display_settings', 0);
    }

    public function test_people_who_do_not_manage_the_mosque_are_refused(): void
    {
        $user = User::factory()->create();
        $this->managerOf(Mosque::factory()->create());
        Mosque::factory()->create()->managers()->attach($user, ['role' => 'owner']);   // manages another one

        $this->actingAs($user)->get("/manage/{$this->mosque->slug}/display")->assertForbidden();

        foreach ($this->writes() as [$method, $url, $data]) {
            $this->actingAs($user)->{$method}($url, $data)->assertForbidden();
        }
        $this->assertDatabaseCount('mosque_display_settings', 0);
        $this->assertDatabaseCount('mosque_display_messages', 0);
    }

    public function test_managers_with_an_unverified_email_are_asked_to_verify_it(): void
    {
        $manager = $this->managerOf($this->mosque);
        $manager->forceFill(['email_verified_at' => null])->save();

        $this->actingAs($manager)->get("/manage/{$this->mosque->slug}/display")->assertRedirect(route('verification.notice'));
        $this->actingAs($manager)->put("/manage/{$this->mosque->slug}/display", ['theme' => 'minimal'])
            ->assertRedirect(route('verification.notice'));

        $this->assertDatabaseCount('mosque_display_settings', 0);
    }

    public function test_managers_open_and_save_the_settings(): void
    {
        $manager = $this->managerOf($this->mosque);

        $this->actingAs($manager)->get("/manage/{$this->mosque->slug}/display")
            ->assertOk()
            ->assertInertia(fn (Assert $page) => $page
                ->component('display/settings')
                ->where('mosque.slug', $this->mosque->slug)
                ->where('settings.theme', 'classic')
                ->where('screenUrl', url("/mosques/{$this->mosque->slug}/display"))
                ->has('options.themes', 4)
                ->has('payload.days', 7)
                ->has('messages', 0));

        $this->actingAs($manager)
            ->put("/manage/{$this->mosque->slug}/display", ['theme' => 'night_sky', 'show_seconds' => false])
            ->assertRedirect()
            ->assertSessionHasNoErrors();

        $row = $this->mosque->displaySetting()->first();
        $this->assertSame('night_sky', $row->settings['theme']);
        $this->assertFalse($row->settings['show_seconds']);
        $this->assertSame($manager->id, $row->updated_by);
    }

    public function test_admins_manage_any_mosque_screen(): void
    {
        $admin = $this->admin();

        $this->actingAs($admin)->get("/manage/{$this->mosque->slug}/display")->assertOk();
        $this->actingAs($admin)->put("/manage/{$this->mosque->slug}/display", ['theme' => 'arabesque'])->assertRedirect();

        $this->assertSame('arabesque', $this->mosque->displaySetting()->first()->settings['theme']);
    }

    public function test_the_screen_offers_its_settings_only_to_managers(): void
    {
        $url = "/mosques/{$this->mosque->slug}/display";

        $this->get($url)->assertOk()->assertInertia(fn (Assert $page) => $page
            ->component('display/screen')
            ->where('mode', 'mosque')
            ->where('settingsUrl', null)
            ->where('payload.mosque.slug', $this->mosque->slug));

        $this->actingAs(User::factory()->create())->get($url)
            ->assertInertia(fn (Assert $page) => $page->where('settingsUrl', null));

        $this->actingAs($this->managerOf($this->mosque))->get($url)
            ->assertInertia(fn (Assert $page) => $page->where('settingsUrl', "/manage/{$this->mosque->slug}/display"));
    }

    public function test_unknown_mosques_and_forged_slugs_are_not_found(): void
    {
        $this->get('/mosques/no-such-mosque/display')->assertNotFound();
        $this->get('/mosques/no-such-mosque/display.json')->assertNotFound();
        $this->get('/mosques/BAD_slug/display')->assertNotFound();
    }
}
