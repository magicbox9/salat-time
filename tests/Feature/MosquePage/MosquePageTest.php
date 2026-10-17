<?php

namespace Tests\Feature\MosquePage;

use App\Models\Mosque;
use App\Models\MosqueClaim;
use App\Models\MosquePost;
use App\Models\PostComment;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Route;
use Inertia\Testing\AssertableInertia as Assert;
use Symfony\Component\HttpKernel\Exception\HttpException;
use Tests\TestCase;

class MosquePageTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        $this->withoutVite();   // pages are checked by Inertia, assets are built separately
    }

    public function test_guests_see_a_mosque_with_its_published_times(): void
    {
        $mosque = Mosque::factory()->withCalendar()->create(['jumua' => '13:30', 'jumua2' => '14:30']);

        $this->get("/mosques/{$mosque->slug}")
            ->assertOk()
            ->assertInertia(fn (Assert $page) => $page
                ->component('mosques/show')
                ->where('mosque.slug', $mosque->slug)
                ->where('mosque.has_times', true)
                ->where('mosque.jumua', ['13:30', '14:30'])
                ->where('live.today.times.fajr', '06:00')
                ->where('live.today.iqama.fajr', '06:10')
                ->has('nearbyWithTimes', 0)
                ->where('viewer.signed_in', false)
                ->where('viewer.can_manage', false)
                ->where('shareUrl', route('mosques.show', $mosque)));
    }

    public function test_a_mosque_without_times_gets_calculated_ones_and_lists_the_nearest_that_publish(): void
    {
        $mosque = Mosque::factory()->at(48.8566, 2.3522)->create();
        $near = Mosque::factory()->withCalendar()->at(48.8600, 2.3500)->create();
        Mosque::factory()->at(48.8580, 2.3530)->create();                 // close, but no times
        Mosque::factory()->withCalendar()->at(45.7640, 4.8357)->create(); // Lyon: farther away

        $this->get("/mosques/{$mosque->slug}")
            ->assertOk()
            ->assertInertia(fn (Assert $page) => $page
                ->component('mosques/show')
                ->where('live.today.source', 'calculated')
                ->where('live.today.iqama.fajr', null)
                ->where('mosque.has_times', false)
                ->has('nearbyWithTimes', 1)
                ->where('nearbyWithTimes.0.slug', $near->slug)
                ->where('nearbyWithTimes.0.has_times', true));
    }

    public function test_the_page_route_only_matches_slugs(): void
    {
        $this->get('/mosques/Not_A_Slug')->assertNotFound();
        $this->get('/mosques/unknown-mosque')->assertNotFound();

        foreach (['/mosques/near.json', '/mosques/search.json'] as $uri) {
            try {
                $route = Route::getRoutes()->match(Request::create($uri));
                $this->assertNotSame('mosques.show', $route->getName(), $uri);
            } catch (HttpException) {
                $this->addToAssertionCount(1);   // no route at all: not captured either
            }
        }
    }

    public function test_drafts_and_scheduled_posts_are_not_public(): void
    {
        $mosque = Mosque::factory()->create();
        $published = MosquePost::factory()->for($mosque)->create(['published_at' => now()->subHour()]);
        MosquePost::factory()->for($mosque)->create(['published_at' => null, 'title' => 'Draft']);
        MosquePost::factory()->for($mosque)->create(['published_at' => now()->addDay(), 'title' => 'Later']);
        MosquePost::factory()->create(['title' => 'Another mosque']);

        $this->get("/mosques/{$mosque->slug}")
            ->assertInertia(fn (Assert $page) => $page
                ->has('pinned', 0)
                ->has('latest', 1)
                ->has('latest.0.posts', 1)
                ->where('latest.0.posts.0.id', $published->id));

        $this->getJson("/mosques/{$mosque->slug}/posts.json")
            ->assertOk()
            ->assertJsonCount(1, 'data');
    }

    public function test_pinned_posts_come_first_then_the_newest(): void
    {
        $mosque = Mosque::factory()->create();
        $pinned = MosquePost::factory()->for($mosque)->create(['pinned' => true, 'published_at' => now()->subDays(10)]);
        $older = MosquePost::factory()->for($mosque)->create(['published_at' => now()->subDays(2)]);
        $newer = MosquePost::factory()->for($mosque)->create(['published_at' => now()->subDay()]);

        $this->get("/mosques/{$mosque->slug}")
            ->assertInertia(fn (Assert $page) => $page
                ->has('pinned', 1)
                ->where('pinned.0.id', $pinned->id)
                ->where('pinned.0.pinned', true)
                ->has('latest.0.posts', 3)
                ->where('latest.0.posts.0.id', $newer->id)
                ->where('latest.0.posts.1.id', $older->id));
    }

    public function test_the_feed_loads_more_with_a_cursor(): void
    {
        $mosque = Mosque::factory()->create();
        foreach (range(1, 12) as $i) {
            MosquePost::factory()->for($mosque)->create(['published_at' => now()->subMinutes($i)]);
        }

        $first = $this->getJson("/mosques/{$mosque->slug}/posts.json")->assertOk();
        $first->assertJsonCount(10, 'data');
        $cursor = $first->json('next_cursor');
        $this->assertNotNull($cursor);

        $second = $this->getJson("/mosques/{$mosque->slug}/posts.json?cursor=".urlencode($cursor))->assertOk();
        $second->assertJsonCount(2, 'data')->assertJsonPath('next_cursor', null);
        $this->assertEmpty(array_intersect(
            array_column($first->json('data'), 'id'),
            array_column($second->json('data'), 'id'),
        ));
    }

    public function test_hidden_comments_are_not_counted_for_the_public(): void
    {
        $mosque = Mosque::factory()->create();
        $post = MosquePost::factory()->for($mosque)->create(['slug' => 'iftar']);
        PostComment::factory()->for($post, 'post')->create();
        PostComment::factory()->for($post, 'post')->create(['hidden_at' => now()]);

        $this->get("/mosques/{$mosque->slug}")
            ->assertInertia(fn (Assert $page) => $page->where('latest.0.posts.0.comments_count', 1));
        $this->get("/mosques/{$mosque->slug}/blog/iftar")
            ->assertInertia(fn (Assert $page) => $page->where('post.comments_count', 1));

        $manager = User::factory()->create();
        $mosque->managers()->attach($manager, ['role' => 'owner']);

        $this->actingAs($manager)->get("/mosques/{$mosque->slug}/blog/iftar")
            ->assertInertia(fn (Assert $page) => $page->where('post.comments_count', 2));
    }

    public function test_the_viewer_flags_come_from_the_database(): void
    {
        $mosque = Mosque::factory()->verified()->create();
        $user = User::factory()->create();
        $user->favoriteMosques()->attach($mosque, ['is_primary' => true]);
        MosqueClaim::factory()->create([
            'mosque_id' => $mosque->id,
            'user_id' => $user->id,
            'status' => MosqueClaim::PENDING,
        ]);

        $this->actingAs($user)->get("/mosques/{$mosque->slug}")
            ->assertInertia(fn (Assert $page) => $page
                ->where('mosque.verified', true)
                ->where('viewer.signed_in', true)
                ->where('viewer.verified', true)
                ->where('viewer.favorite', true)
                ->where('viewer.primary', true)
                ->where('viewer.can_manage', false)
                ->where('viewer.pending_claim', true));

        $manager = User::factory()->create();
        $mosque->managers()->attach($manager, ['role' => 'owner']);

        $this->actingAs($manager)->get("/mosques/{$mosque->slug}")
            ->assertInertia(fn (Assert $page) => $page
                ->where('viewer.can_manage', true)
                ->where('viewer.favorite', false));
    }

    public function test_unsafe_websites_are_not_linked(): void
    {
        $mosque = Mosque::factory()->create(['website' => 'javascript:alert(1)']);

        $this->get("/mosques/{$mosque->slug}")
            ->assertInertia(fn (Assert $page) => $page->where('mosque.website', null));

        $mosque->update(['website' => 'mosquee-exemple.fr']);

        $this->get("/mosques/{$mosque->slug}")
            ->assertInertia(fn (Assert $page) => $page->where('mosque.website', 'https://mosquee-exemple.fr'));
    }
}
