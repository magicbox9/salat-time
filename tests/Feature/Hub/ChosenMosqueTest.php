<?php

namespace Tests\Feature\Hub;

use App\Http\Controllers\Discover\FavoriteMosqueController;
use App\Models\Mosque;
use App\Models\User;
use App\Support\ChosenMosque;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Tests\TestCase;

/** The visitor's own mosque: primary saved mosque, guest cookie, sign-in adoption. */
class ChosenMosqueTest extends TestCase
{
    use RefreshDatabase;

    private function requestWith(?User $user, ?string $cookie): Request
    {
        $request = Request::create('/');
        if ($cookie !== null) {
            $request->cookies->set(ChosenMosque::COOKIE, $cookie);
        }
        $request->setUserResolver(fn () => $user);

        return $request;
    }

    private function primaryOf(User $user): ?int
    {
        return DB::table('favorite_mosques')->where('user_id', $user->id)->where('is_primary', true)->value('mosque_id');
    }

    public function test_a_signed_in_user_resolves_to_their_primary_mosque(): void
    {
        $user = User::factory()->create();
        $own = Mosque::factory()->create();
        $other = Mosque::factory()->create();
        $user->favoriteMosques()->attach([$other->id => ['is_primary' => false], $own->id => ['is_primary' => true]]);

        // The account's choice wins over a guest cookie.
        $this->assertTrue(ChosenMosque::for($this->requestWith($user, $other->slug))->is($own));
    }

    public function test_a_guest_resolves_to_the_cookie_mosque(): void
    {
        $mosque = Mosque::factory()->create();

        $this->assertTrue(ChosenMosque::for($this->requestWith(null, $mosque->slug))->is($mosque));
    }

    public function test_nothing_is_chosen_without_primary_or_cookie(): void
    {
        Mosque::factory()->create();

        $this->assertNull(ChosenMosque::for($this->requestWith(null, null)));
        $this->assertNull(ChosenMosque::for($this->requestWith(User::factory()->create(), null)));
    }

    public function test_a_stale_or_forged_cookie_is_ignored(): void
    {
        $this->assertNull(ChosenMosque::for($this->requestWith(null, 'gone-mosque')));
        $this->assertNull(ChosenMosque::for($this->requestWith(null, "x' OR 1=1 --")));
        $this->assertNull(ChosenMosque::for($this->requestWith(null, str_repeat('a', 300))));
    }

    public function test_a_guest_chooses_a_mosque_with_an_encrypted_cookie(): void
    {
        $mosque = Mosque::factory()->create();

        $this->post(route('my-mosque.store'), ['slug' => $mosque->slug])
            ->assertRedirect(route('home'))
            ->assertCookie(ChosenMosque::COOKIE, $mosque->slug);

        $this->assertDatabaseCount('favorite_mosques', 0);
    }

    public function test_the_cookie_lasts_a_year_and_is_http_only(): void
    {
        $mosque = Mosque::factory()->create();

        $cookie = collect($this->postJson(route('my-mosque.store'), ['slug' => $mosque->slug])
            ->assertOk()
            ->assertJson(['slug' => $mosque->slug, 'chosen' => true, 'redirect' => route('home')])
            ->headers->getCookies())
            ->first(fn ($c) => $c->getName() === ChosenMosque::COOKIE);

        $this->assertNotNull($cookie);
        $this->assertTrue($cookie->isHttpOnly());
        $this->assertSame('lax', $cookie->getSameSite());
        $this->assertGreaterThan(now()->addDays(360)->getTimestamp(), $cookie->getExpiresTime());
    }

    public function test_a_user_chooses_a_mosque_as_their_primary_one(): void
    {
        $user = User::factory()->create();
        [$first, $second] = Mosque::factory()->count(2)->create();

        $this->actingAs($user)->post(route('my-mosque.store'), ['slug' => $first->slug])->assertRedirect(route('home'));
        $this->assertSame($first->id, $this->primaryOf($user));

        $this->actingAs($user)->postJson(route('my-mosque.store'), ['slug' => $second->slug])->assertOk();
        $this->assertSame($second->id, $this->primaryOf($user));
        // The previous one stays saved.
        $this->assertSame(2, DB::table('favorite_mosques')->where('user_id', $user->id)->count());
    }

    public function test_choosing_validates_the_slug(): void
    {
        $this->postJson(route('my-mosque.store'), [])->assertJsonValidationErrors('slug');
        $this->postJson(route('my-mosque.store'), ['slug' => 'Not A Slug'])->assertJsonValidationErrors('slug');
        $this->postJson(route('my-mosque.store'), ['slug' => ['array']])->assertJsonValidationErrors('slug');
        $this->postJson(route('my-mosque.store'), ['slug' => 'no-such-mosque'])->assertJsonValidationErrors('slug');
    }

    public function test_a_full_list_of_saved_mosques_is_refused(): void
    {
        $user = User::factory()->create();
        $user->favoriteMosques()->attach(Mosque::factory()->count(FavoriteMosqueController::MAX)->create()->modelKeys());
        $new = Mosque::factory()->create();

        $this->actingAs($user)->postJson(route('my-mosque.store'), ['slug' => $new->slug])->assertJsonValidationErrors('mosque');
        $this->assertNull($this->primaryOf($user));
    }

    public function test_a_guest_clears_their_choice(): void
    {
        $mosque = Mosque::factory()->create();

        $this->withCookie(ChosenMosque::COOKIE, $mosque->slug)
            ->delete(route('my-mosque.destroy'))
            ->assertRedirect(route('explore'))
            ->assertCookieExpired(ChosenMosque::COOKIE);
    }

    public function test_a_user_clears_their_own_mosque_but_keeps_it_saved(): void
    {
        $user = User::factory()->create();
        $mosque = Mosque::factory()->create();
        $user->favoriteMosques()->attach($mosque->id, ['is_primary' => true]);

        $this->actingAs($user)->deleteJson(route('my-mosque.destroy'))->assertOk()->assertJson(['chosen' => false]);

        $this->assertNull($this->primaryOf($user));
        $this->assertDatabaseHas('favorite_mosques', ['user_id' => $user->id, 'mosque_id' => $mosque->id]);
    }

    public function test_signing_in_adopts_the_guest_choice_when_the_user_has_none(): void
    {
        $user = User::factory()->create();
        $mosque = Mosque::factory()->create();

        $this->withCookie(ChosenMosque::COOKIE, $mosque->slug)
            ->post(route('login.store'), ['email' => $user->email, 'password' => 'password'])
            ->assertCookieExpired(ChosenMosque::COOKIE);

        $this->assertAuthenticatedAs($user);
        $this->assertSame($mosque->id, $this->primaryOf($user));
    }

    public function test_signing_in_keeps_the_users_own_mosque(): void
    {
        $user = User::factory()->create();
        $own = Mosque::factory()->create();
        $guestChoice = Mosque::factory()->create();
        $user->favoriteMosques()->attach($own->id, ['is_primary' => true]);

        $this->withCookie(ChosenMosque::COOKIE, $guestChoice->slug)
            ->post(route('login.store'), ['email' => $user->email, 'password' => 'password']);

        $this->assertSame($own->id, $this->primaryOf($user));
        $this->assertDatabaseMissing('favorite_mosques', ['user_id' => $user->id, 'mosque_id' => $guestChoice->id]);
    }

    public function test_the_first_page_after_sign_in_adopts_the_guest_choice_too(): void
    {
        $user = User::factory()->create();
        $mosque = Mosque::factory()->withCalendar()->create();

        // Signed in without the listener having seen the cookie (e.g. another tab).
        $this->actingAs($user)
            ->withCookie(ChosenMosque::COOKIE, $mosque->slug)
            ->withoutVite()
            ->get(route('home'))
            ->assertOk()
            ->assertCookieExpired(ChosenMosque::COOKIE);

        $this->assertSame($mosque->id, $this->primaryOf($user));
    }

    public function test_no_longer_my_mosque_from_my_mosques_forgets_the_guest_cookie(): void
    {
        $user = User::factory()->create();
        $mosque = Mosque::factory()->create();
        $user->favoriteMosques()->attach($mosque->id, ['is_primary' => true]);

        $this->actingAs($user)
            ->withCookie(ChosenMosque::COOKIE, $mosque->slug)
            ->deleteJson("/mosques/{$mosque->slug}/primary")
            ->assertOk()
            ->assertCookieExpired(ChosenMosque::COOKIE);

        $this->assertNull($this->primaryOf($user));
    }
}
