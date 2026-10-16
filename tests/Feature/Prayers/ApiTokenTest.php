<?php

namespace Tests\Feature\Prayers;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Inertia\Testing\AssertableInertia as Assert;
use Laravel\Sanctum\PersonalAccessToken;
use Tests\TestCase;

/** Settings → Companion app: personal access tokens. */
class ApiTokenTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        $this->withoutVite();
    }

    private function confirmed(User $user): static
    {
        return $this->actingAs($user)->withSession(['auth.password_confirmed_at' => time()]);
    }

    public function test_guests_and_unverified_users_cannot_manage_tokens(): void
    {
        $this->get('/settings/api-tokens')->assertRedirect('/login');
        $this->post('/settings/api-tokens', ['name' => 'Phone'])->assertRedirect('/login');

        $unverified = User::factory()->unverified()->create();
        $this->confirmed($unverified)->post('/settings/api-tokens', ['name' => 'Phone'])
            ->assertRedirect(route('verification.notice'));
        $this->assertDatabaseCount('personal_access_tokens', 0);
    }

    public function test_the_page_asks_for_the_password_first(): void
    {
        $user = User::factory()->create();

        $this->actingAs($user)->get('/settings/api-tokens')->assertRedirect(route('password.confirm'));
    }

    public function test_the_page_lists_only_my_tokens(): void
    {
        $user = User::factory()->create();
        $user->createToken('My iPhone', ['prayers:read', 'prayers:write']);
        User::factory()->create()->createToken('Someone else');

        $this->confirmed($user)->get('/settings/api-tokens')
            ->assertOk()
            ->assertInertia(fn (Assert $page) => $page
                ->component('settings/api-tokens')
                ->has('tokens', 1)
                ->where('tokens.0.name', 'My iPhone')
                ->missing('tokens.0.token'));
    }

    public function test_a_token_is_created_shown_once_and_works_on_the_api(): void
    {
        $user = User::factory()->create();

        $this->confirmed($user)->post('/settings/api-tokens', ['name' => 'My iPhone'])
            ->assertRedirect('/settings/api-tokens')
            ->assertInertiaFlash('newToken.name', 'My iPhone');

        $token = PersonalAccessToken::query()->sole();
        $this->assertSame($user->id, (int) $token->tokenable_id);
        $this->assertSame(['prayers:read', 'prayers:write'], $token->abilities);
        $this->assertTrue($token->expires_at->isFuture());

        // Shown once, through the flash data of the redirect.
        $plain = session('inertia.flash_data.newToken.token');
        $this->assertIsString($plain);

        $this->app['auth']->forgetGuards();
        $this->withToken($plain)->getJson('/api/v1/me')->assertOk()->assertJsonPath('data.id', $user->id);
    }

    public function test_the_name_is_validated(): void
    {
        $user = User::factory()->create();

        $this->confirmed($user)->post('/settings/api-tokens', ['name' => ''])->assertSessionHasErrors('name');
        $this->confirmed($user)->post('/settings/api-tokens', ['name' => str_repeat('x', 61)])->assertSessionHasErrors('name');
        $this->assertDatabaseCount('personal_access_tokens', 0);
    }

    public function test_the_number_of_tokens_is_limited(): void
    {
        $user = User::factory()->create();
        for ($i = 0; $i < 10; $i++) {
            $user->createToken("Device $i");
        }

        $this->confirmed($user)->post('/settings/api-tokens', ['name' => 'One more'])->assertSessionHasErrors('name');
        $this->assertDatabaseCount('personal_access_tokens', 10);
    }

    public function test_people_revoke_only_their_own_tokens(): void
    {
        $user = User::factory()->create();
        $mine = $user->createToken('Mine')->accessToken;
        $theirs = User::factory()->create()->createToken('Theirs')->accessToken;

        $this->actingAs($user)->delete("/settings/api-tokens/{$theirs->id}")->assertNotFound();
        $this->assertModelExists($theirs);

        $this->actingAs($user)->delete("/settings/api-tokens/{$mine->id}")->assertRedirect('/settings/api-tokens');
        $this->assertModelMissing($mine);
    }
}
