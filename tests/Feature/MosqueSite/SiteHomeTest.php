<?php

namespace Tests\Feature\MosqueSite;

use App\Models\Campaign;
use App\Models\Mosque;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Inertia\Testing\AssertableInertia as Assert;
use Tests\TestCase;

/** The mosque's home page: the site shell, its menu, and the blog pieces around the times. */
class SiteHomeTest extends TestCase
{
    use BuildsMosqueSites, RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        $this->withoutVite();
    }

    public function test_the_shell_carries_the_look_and_the_menu_of_the_site(): void
    {
        $mosque = Mosque::factory()->verified()->withCalendar()->create([
            'tagline' => 'Un lieu de prière et de savoir',
            'accent_color' => '#A37A33',
            'social_links' => ['instagram' => 'https://www.instagram.com/elhouda', 'facebook' => 'javascript:alert(1)'],
        ]);
        $this->category($mosque, 'Khutbah', 'khutbah');
        $this->sitePage($mosque, ['title' => 'Cours', 'slug' => 'cours', 'sort' => 2]);
        $this->sitePage($mosque, ['title' => 'À propos', 'slug' => 'a-propos', 'sort' => 1]);
        $this->sitePage($mosque, ['title' => 'Brouillon', 'slug' => 'brouillon', 'published_at' => null]);
        $this->sitePage($mosque, ['title' => 'Caché', 'slug' => 'cache', 'show_in_menu' => false]);
        $this->sitePage($mosque, ['title' => 'Contact', 'slug' => 'contact', 'sort' => 9]);

        $this->get("/mosques/{$mosque->slug}")
            ->assertOk()
            ->assertInertia(fn (Assert $page) => $page
                ->component('mosques/show')
                ->where('site.slug', $mosque->slug)
                ->where('site.tagline', 'Un lieu de prière et de savoir')
                ->where('site.verified', true)
                ->where('site.accent.color', '#a37a33')
                ->where('site.accent.foreground', '#0b1a17')
                ->where('site.menu', [['title' => 'À propos', 'slug' => 'a-propos'], ['title' => 'Cours', 'slug' => 'cours']])
                ->where('site.contact_page', 'contact')
                ->where('site.khutbah', true)
                ->where('site.donate', false)
                ->where('mosque.tagline', 'Un lieu de prière et de savoir')
                ->where('mosque.social_links', [['network' => 'instagram', 'url' => 'https://www.instagram.com/elhouda']])
                ->where('aboutPage.slug', 'a-propos')
                ->where('meta.title', $mosque->name)
                ->where('meta.description', 'Un lieu de prière et de savoir'));
    }

    public function test_donate_appears_only_with_an_open_campaign(): void
    {
        $mosque = Mosque::factory()->verified()->create();
        $user = $this->managerOf($mosque);
        Campaign::factory()->for($mosque)->create(['created_by' => $user->id, 'status' => 'draft']);

        $this->get("/mosques/{$mosque->slug}")->assertInertia(fn (Assert $page) => $page->where('site.donate', false));

        Campaign::factory()->for($mosque)->active()->create(['created_by' => $user->id]);

        $this->get("/mosques/{$mosque->slug}")->assertInertia(fn (Assert $page) => $page->where('site.donate', true));
    }

    public function test_the_home_groups_the_latest_posts_by_category_and_lists_upcoming_events(): void
    {
        $mosque = Mosque::factory()->create();
        $news = $this->category($mosque, 'Actualités', 'news', 1);
        $khutbah = $this->category($mosque, 'Khutbah', 'khutbah', 0);
        $this->blogPost($mosque, ['category_id' => $news->id, 'title' => 'Travaux', 'published_at' => now()->subDays(1)]);
        $this->blogPost($mosque, ['category_id' => $khutbah->id, 'title' => 'La patience', 'published_at' => now()->subDays(3)]);
        $this->blogPost($mosque, ['title' => 'Sans catégorie', 'published_at' => now()->subDays(2)]);
        $this->blogPost($mosque, ['type' => 'event', 'title' => 'Iftar collectif', 'event_starts_at' => now()->addDays(4)]);
        $this->blogPost($mosque, ['type' => 'event', 'title' => 'Passé', 'event_starts_at' => now()->subDays(4)]);
        $this->blogPost($mosque, ['type' => 'event', 'title' => 'Brouillon', 'event_starts_at' => now()->addDay(), 'published_at' => null]);
        $this->blogPost($mosque, ['pinned' => true, 'title' => 'Collecte du vendredi']);

        $this->get("/mosques/{$mosque->slug}")
            ->assertInertia(fn (Assert $page) => $page
                ->where('latest.0.category.slug', 'khutbah')
                ->where('latest.0.posts.0.title', 'La patience')
                ->where('latest.0.posts.0.url', fn (string $url) => str_starts_with($url, "/mosques/{$mosque->slug}/blog/"))
                ->where('latest.1.category.slug', 'news')
                ->where('latest.2.category', null)
                ->has('events', 1)
                ->where('events.0.title', 'Iftar collectif')
                ->has('pinned', 1)
                ->where('pinned.0.title', 'Collecte du vendredi'));
    }

    public function test_posts_without_an_address_get_one_when_shown(): void
    {
        $mosque = Mosque::factory()->create();
        $post = $this->blogPost($mosque, ['slug' => null, 'title' => 'Cours de tajwid']);

        $this->get("/mosques/{$mosque->slug}")
            ->assertInertia(fn (Assert $page) => $page
                ->where('latest.0.posts.0.url', "/mosques/{$mosque->slug}/blog/cours-de-tajwid"));

        $this->assertSame('cours-de-tajwid', $post->fresh()->slug);
    }

    public function test_old_post_links_redirect_to_the_article(): void
    {
        $mosque = Mosque::factory()->create();
        $post = $this->blogPost($mosque, ['slug' => null, 'title' => 'Janaza de notre frère']);
        $draft = $this->blogPost($mosque, ['published_at' => null]);
        $foreign = $this->blogPost(Mosque::factory()->create());

        $this->get("/mosques/{$mosque->slug}/posts/{$post->id}")
            ->assertStatus(301)
            ->assertRedirect("/mosques/{$mosque->slug}/blog/janaza-de-notre-frere");
        $this->get("/mosques/{$mosque->slug}/posts/{$draft->id}")->assertNotFound();
        $this->get("/mosques/{$mosque->slug}/posts/{$foreign->id}")->assertNotFound();
        $this->get("/mosques/{$mosque->slug}/posts/99999999999999999999")->assertNotFound();
    }

    public function test_a_partial_reload_of_the_viewer_skips_the_site_queries(): void
    {
        $mosque = Mosque::factory()->create();
        $response = $this->get("/mosques/{$mosque->slug}")->assertOk();

        $response->assertInertia(fn (Assert $page) => $page->reloadOnly('viewer', fn (Assert $reload) => $reload
            ->missing('site')
            ->missing('latest')
            ->missing('events')));
    }
}
