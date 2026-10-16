<?php

namespace Tests\Feature\Discover;

use App\Models\Mosque;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Inertia\Testing\AssertableInertia as Assert;
use Tests\TestCase;

class DiscoverPagesTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        // Pages are checked as Inertia responses; the built assets may be older than the page files.
        $this->withoutVite();
    }

    public function test_guests_get_the_globe_without_saved_mosques(): void
    {
        $this->get(route('home'))
            ->assertOk()
            ->assertInertia(fn (Assert $page) => $page
                ->component('home')
                ->where('initialCountry', 'FR')
                ->has('favorites', 0)
                ->where('primary', null));
    }

    public function test_signed_in_visitors_get_their_mosques_and_their_own_mosque(): void
    {
        $user = User::factory()->create();
        $own = Mosque::factory()->withCalendar()->create(['name' => 'Zawiya']);
        $saved = Mosque::factory()->create(['name' => 'Al Amal']);
        Mosque::factory()->create();
        $user->favoriteMosques()->attach([$own->id => ['is_primary' => true], $saved->id => ['is_primary' => false]]);

        $this->actingAs($user)
            ->get(route('home'))
            ->assertOk()
            ->assertInertia(fn (Assert $page) => $page
                ->component('home')
                ->has('favorites', 2)
                ->where('favorites.0.id', $own->id)          // own mosque first
                ->where('favorites.0.is_primary', true)
                ->where('favorites.0.has_times', true)
                ->where('favorites.1.id', $saved->id)
                ->where('favorites.1.is_favorite', true)
                ->where('primary.slug', $own->slug));
    }

    public function test_my_mosques_lists_saved_mosques_with_todays_times(): void
    {
        $user = User::factory()->create();
        $own = Mosque::factory()->withCalendar()->create(['name' => 'Zawiya']);
        $saved = Mosque::factory()->create(['name' => 'Al Amal']);
        $user->favoriteMosques()->attach([$saved->id => ['is_primary' => false], $own->id => ['is_primary' => true]]);
        // Someone else's mosques never show.
        User::factory()->create()->favoriteMosques()->attach(Mosque::factory()->create()->id);

        $this->actingAs($user)
            ->get(route('me.mosques'))
            ->assertOk()
            ->assertInertia(fn (Assert $page) => $page
                ->component('me/mosques')
                ->has('mosques', 2)
                ->where('mosques.0.slug', $own->slug)
                ->where('mosques.0.is_primary', true)
                ->where('mosques.0.today.times.fajr', '06:00')
                ->has('mosques.0.tomorrow.times')
                ->where('mosques.1.slug', $saved->slug)
                ->where('mosques.1.today', null));
    }

    public function test_my_mosques_requires_a_verified_account(): void
    {
        $this->get(route('me.mosques'))->assertRedirect(route('login'));

        $this->actingAs(User::factory()->unverified()->create())
            ->get(route('me.mosques'))
            ->assertRedirect(route('verification.notice'));
    }
}
