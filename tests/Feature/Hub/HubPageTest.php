<?php

namespace Tests\Feature\Hub;

use App\Http\Middleware\HandleInertiaRequests;
use App\Models\Mosque;
use App\Models\MosquePost;
use App\Models\MosquePostCategory;
use App\Models\PrayerLog;
use App\Models\User;
use App\Support\ChosenMosque;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Inertia\Testing\AssertableInertia as Assert;
use Tests\TestCase;

/** "/" is the hub of the visitor's own mosque once chosen, the globe before; "/explore" is always the globe. */
class HubPageTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        $this->withoutVite();
    }

    public function test_home_is_the_globe_without_a_chosen_mosque(): void
    {
        $this->get(route('home'))->assertOk()->assertInertia(fn (Assert $page) => $page->component('home'));
        $this->actingAs(User::factory()->create())
            ->get(route('home'))
            ->assertOk()
            ->assertInertia(fn (Assert $page) => $page->component('home'));
    }

    public function test_home_is_the_hub_of_the_users_own_mosque(): void
    {
        $user = User::factory()->create();
        $mosque = Mosque::factory()->withCalendar()->create(['name' => 'Masjid an-Nur', 'tagline' => 'Une mosquée ouverte']);
        $user->favoriteMosques()->attach($mosque->id, ['is_primary' => true]);

        $this->actingAs($user)
            ->get(route('home'))
            ->assertOk()
            ->assertInertia(fn (Assert $page) => $page
                ->component('hub/index')
                ->where('mosque.slug', $mosque->slug)
                ->where('mosque.name', 'Masjid an-Nur')
                ->where('mosque.tagline', 'Une mosquée ouverte')
                ->where('mosque.has_times', true)
                ->where('chosenBy', 'user')
                ->where('live.timezone', 'Europe/Paris')
                ->where('live.today.times.fajr', '06:00')
                ->where('live.today.iqama.fajr', '06:10')
                ->has('live.tomorrow.times')
                ->where('nearbyWithTimes', [])
                ->where('preferences.style', 'cards')
                ->where('defaults.adhan', 'visual')
                ->has('tracker.logs', 5)
                ->where('canManage', false));
    }

    public function test_home_is_the_hub_of_a_guests_cookie_mosque(): void
    {
        $mosque = Mosque::factory()->withCalendar()->create();

        $this->withCookie(ChosenMosque::COOKIE, $mosque->slug)
            ->get(route('home'))
            ->assertOk()
            ->assertInertia(fn (Assert $page) => $page
                ->component('hub/index')
                ->where('mosque.slug', $mosque->slug)
                ->where('chosenBy', 'cookie')
                ->where('preferences', null)
                ->where('tracker', null));
    }

    public function test_explore_is_always_the_globe(): void
    {
        $mosque = Mosque::factory()->withCalendar()->create();
        $user = User::factory()->create();
        $user->favoriteMosques()->attach($mosque->id, ['is_primary' => true]);

        $this->actingAs($user)
            ->get(route('explore'))
            ->assertOk()
            ->assertInertia(fn (Assert $page) => $page->component('home')->where('primary.slug', $mosque->slug));
    }

    public function test_a_guest_globe_flies_to_the_cookie_mosque(): void
    {
        $mosque = Mosque::factory()->create();

        $this->withCookie(ChosenMosque::COOKIE, $mosque->slug)
            ->get(route('explore'))
            ->assertOk()
            ->assertInertia(fn (Assert $page) => $page
                ->component('home')
                ->has('favorites', 0)
                ->where('primary.slug', $mosque->slug)
                ->where('primary.is_primary', true)
                ->where('primary.is_favorite', false));
    }

    public function test_the_hub_lists_only_published_posts_newest_first(): void
    {
        $mosque = Mosque::factory()->withCalendar()->create();
        $category = MosquePostCategory::query()->create(['mosque_id' => $mosque->id, 'name' => 'Khutbah', 'slug' => 'khutbah']);
        MosquePost::factory()->for($mosque)->create(['title' => 'Older', 'published_at' => now()->subDays(3)]);
        MosquePost::factory()->for($mosque)->create([
            'title' => 'Newest', 'slug' => 'newest', 'category_id' => $category->id, 'excerpt' => 'Short summary', 'published_at' => now()->subHour(),
        ]);
        MosquePost::factory()->for($mosque)->create(['title' => 'Draft', 'published_at' => null]);
        MosquePost::factory()->for($mosque)->create(['title' => 'Scheduled', 'published_at' => now()->addDay()]);
        MosquePost::factory()->create(['title' => 'Other mosque']);

        $this->withCookie(ChosenMosque::COOKIE, $mosque->slug)
            ->get(route('home'))
            ->assertInertia(fn (Assert $page) => $page
                ->has('posts', 2)
                ->where('posts.0.title', 'Newest')
                ->where('posts.0.category', 'Khutbah')
                ->where('posts.0.excerpt', 'Short summary')
                ->where('posts.0.url', "/mosques/{$mosque->slug}/blog/newest")
                ->where('posts.1.title', 'Older')
                ->where('posts.1.url', "/mosques/{$mosque->slug}"));
    }

    public function test_a_mosque_without_times_offers_nearby_mosques_that_publish_them(): void
    {
        $silent = Mosque::factory()->at(45.75, 4.85)->create(['source' => 'osm']);
        $near = Mosque::factory()->withCalendar()->at(45.76, 4.86)->create();
        Mosque::factory()->at(45.77, 4.84)->create(['source' => 'osm']);   // no times: not offered

        $this->withCookie(ChosenMosque::COOKIE, $silent->slug)
            ->get(route('home'))
            ->assertOk()
            ->assertInertia(fn (Assert $page) => $page
                ->component('hub/index')
                ->where('live.today', null)
                ->where('mosque.has_times', false)
                ->has('nearbyWithTimes', 1)
                ->where('nearbyWithTimes.0.slug', $near->slug)
                ->where('nearbyWithTimes.0.today.times.fajr', '06:00'));
    }

    public function test_the_tracker_shows_todays_logs_for_verified_users_only(): void
    {
        $user = User::factory()->create();
        $mosque = Mosque::factory()->withCalendar()->create();
        $user->favoriteMosques()->attach($mosque->id, ['is_primary' => true]);
        $today = now('Europe/Paris')->toDateString();
        PrayerLog::factory()->create([
            'user_id' => $user->id, 'prayer_date' => $today, 'prayer' => 'fajr', 'status' => 'on_time', 'place' => 'home', 'hasanat' => 10,
        ]);

        $this->actingAs($user)
            ->get(route('home'))
            ->assertInertia(fn (Assert $page) => $page
                ->where('tracker.date', $today)
                ->where('tracker.logs.fajr.status', 'on_time')
                ->where('tracker.logs.dhuhr', null));

        $unverified = User::factory()->unverified()->create();
        $unverified->favoriteMosques()->attach($mosque->id, ['is_primary' => true]);
        $this->actingAs($unverified)
            ->get(route('home'))
            ->assertInertia(fn (Assert $page) => $page->component('hub/index')->where('tracker', null));
    }

    public function test_the_evening_before_comes_along_while_its_isha_falls_after_midnight(): void
    {
        // Summer timetables publish Isha after midnight: that Isha belongs to
        // the evening before, which the page keeps until it is over.
        $summer = Mosque::factory()->withCalendar(['03:40', '05:36', '14:00', '18:03', '21:56', '00:02'])->create();
        $yesterday = now('Europe/Paris')->subDay()->toDateString();

        $this->withCookie(ChosenMosque::COOKIE, $summer->slug)
            ->get(route('home'))
            ->assertInertia(fn (Assert $page) => $page
                ->where('live.yesterday.date', $yesterday)
                ->where('live.yesterday.times.isha', '00:02')
                ->where('live.yesterday.iqama.isha', '00:12'));

        // An ordinary day (or a mistyped Isha past Fajr) needs no evening before.
        $plain = Mosque::factory()->withCalendar()->create();
        $typo = Mosque::factory()->withCalendar(['05:00', '06:30', '13:00', '16:00', '19:00', '09:45'])->create();
        foreach ([$plain, $typo] as $mosque) {
            $this->withCookie(ChosenMosque::COOKIE, $mosque->slug)
                ->get(route('home'))
                ->assertInertia(fn (Assert $page) => $page->where('live.yesterday', null)->has('live.today.times'));
        }
    }

    public function test_the_tracker_also_carries_the_day_before(): void
    {
        $user = User::factory()->create();
        $mosque = Mosque::factory()->withCalendar()->create();
        $user->favoriteMosques()->attach($mosque->id, ['is_primary' => true]);
        $yesterday = now('Europe/Paris')->subDay()->toDateString();
        PrayerLog::factory()->create([
            'user_id' => $user->id, 'prayer_date' => $yesterday, 'prayer' => 'isha', 'status' => 'on_time', 'place' => 'home', 'hasanat' => 10,
        ]);

        $this->actingAs($user)
            ->get(route('home'))
            ->assertInertia(fn (Assert $page) => $page
                ->where('tracker.date', now('Europe/Paris')->toDateString())
                ->where('tracker.logs.isha', null)
                ->where('tracker.previous.date', $yesterday)
                ->where('tracker.previous.logs.isha.status', 'on_time')
                ->where('tracker.previous.logs.fajr', null));
    }

    public function test_managers_are_told_they_manage_the_mosque(): void
    {
        $user = User::factory()->create();
        $mosque = Mosque::factory()->withCalendar()->create();
        $user->favoriteMosques()->attach($mosque->id, ['is_primary' => true]);
        $mosque->managers()->attach($user->id, ['role' => 'owner']);

        $this->actingAs($user)
            ->get(route('home'))
            ->assertInertia(fn (Assert $page) => $page->where('canManage', true));
    }

    public function test_a_partial_reload_after_midnight_returns_only_the_live_props(): void
    {
        $mosque = Mosque::factory()->withCalendar()->create();
        $version = app(HandleInertiaRequests::class)->version(request());

        $this->withCookie(ChosenMosque::COOKIE, $mosque->slug)
            ->withHeaders([
                'X-Inertia' => 'true',
                'X-Inertia-Version' => (string) $version,
                'X-Inertia-Partial-Component' => 'hub/index',
                'X-Inertia-Partial-Data' => 'live,tracker',
            ])
            ->get(route('home'))
            ->assertOk()
            ->assertJsonPath('props.live.today.times.fajr', '06:00')
            ->assertJsonMissingPath('props.posts')
            ->assertJsonMissingPath('props.mosque');
    }
}
