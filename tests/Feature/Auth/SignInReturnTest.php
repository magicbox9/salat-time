<?php

namespace Tests\Feature\Auth;

use App\Models\Mosque;
use App\Models\User;
use App\Support\ChosenMosque;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Inertia\Testing\AssertableInertia as Assert;
use Tests\TestCase;

/** "Sign in to do this" brings the guest back to the page they were on. */
class SignInReturnTest extends TestCase
{
    use RefreshDatabase;

    public function test_a_guest_signing_in_comes_back_to_the_page_they_were_on(): void
    {
        $user = User::factory()->create();
        $mosque = Mosque::factory()->create();
        $page = "/mosques/{$mosque->slug}";

        $this->get('/sign-in?return='.urlencode($page))
            ->assertRedirect(route('login'))
            ->assertSessionHas('url.intended', url($page));

        $this->post(route('login.store'), ['email' => $user->email, 'password' => 'password'])
            ->assertRedirect($page);
        $this->assertAuthenticatedAs($user);
    }

    public function test_only_paths_on_this_site_are_remembered(): void
    {
        foreach (['//evil.example/x', 'https://evil.example/x', '/\\evil.example', "/x\nSet-Cookie: a=b", 'mosques/x', ''] as $unsafe) {
            $this->get('/sign-in?return='.urlencode($unsafe))
                ->assertRedirect(route('login'))
                ->assertSessionMissing('url.intended');
        }
    }

    public function test_a_signed_in_visitor_goes_straight_back(): void
    {
        $this->actingAs(User::factory()->create())
            ->get('/sign-in?return='.urlencode('/quran/2'))
            ->assertRedirect('/quran/2');
    }

    public function test_a_guests_own_mosque_shows_as_theirs_on_its_page(): void
    {
        $mine = Mosque::factory()->create();
        $other = Mosque::factory()->create();

        $this->withCookie(ChosenMosque::COOKIE, $mine->slug)
            ->get("/mosques/{$mine->slug}")
            ->assertInertia(fn (Assert $page) => $page
                ->where('viewer.signed_in', false)
                ->where('viewer.primary', true)
                ->where('viewer.favorite', false));

        $this->withCookie(ChosenMosque::COOKIE, $mine->slug)
            ->get("/mosques/{$other->slug}")
            ->assertInertia(fn (Assert $page) => $page->where('viewer.primary', false));
    }
}
