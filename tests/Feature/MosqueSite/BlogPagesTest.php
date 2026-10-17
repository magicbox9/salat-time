<?php

namespace Tests\Feature\MosqueSite;

use App\Models\Mosque;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Route;
use Inertia\Testing\AssertableInertia as Assert;
use Symfony\Component\HttpKernel\Exception\HttpException;
use Tests\TestCase;

/** The public blog: list, filters, search, articles, and what drafts and scheduled posts look like. */
class BlogPagesTest extends TestCase
{
    use BuildsMosqueSites, RefreshDatabase;

    private Mosque $mosque;

    protected function setUp(): void
    {
        parent::setUp();
        $this->withoutVite();
        $this->mosque = Mosque::factory()->create();
    }

    public function test_the_blog_lists_only_published_posts_newest_first(): void
    {
        $older = $this->blogPost($this->mosque, ['published_at' => now()->subDays(2)]);
        $newer = $this->blogPost($this->mosque, ['published_at' => now()->subDay()]);
        $this->blogPost($this->mosque, ['published_at' => null]);
        $this->blogPost($this->mosque, ['published_at' => now()->addHour()]);
        $this->blogPost(Mosque::factory()->create());

        $this->get("/mosques/{$this->mosque->slug}/blog")
            ->assertOk()
            ->assertInertia(fn (Assert $page) => $page
                ->component('mosques/blog')
                ->where('site.slug', $this->mosque->slug)
                ->has('posts.data', 2)
                ->where('posts.data.0.id', $newer->id)
                ->where('posts.data.1.id', $older->id)
                ->missing('posts.data.0.body')
                ->where('filters', ['category' => null, 'q' => '']));
    }

    public function test_the_blog_filters_by_category_and_ignores_unknown_ones(): void
    {
        $khutbah = $this->category($this->mosque, 'Khutbah', 'khutbah');
        $sermon = $this->blogPost($this->mosque, ['category_id' => $khutbah->id]);
        $this->blogPost($this->mosque);
        $this->blogPost($this->mosque, ['category_id' => $khutbah->id, 'published_at' => null]);

        $this->get("/mosques/{$this->mosque->slug}/blog?category=khutbah")
            ->assertInertia(fn (Assert $page) => $page
                ->has('posts.data', 1)
                ->where('posts.data.0.id', $sermon->id)
                ->where('posts.data.0.category.slug', 'khutbah')
                ->where('filters.category', 'khutbah')
                ->where('activeCategory.name', 'Khutbah')
                ->where('categories.0.posts_count', 1));

        $this->get("/mosques/{$this->mosque->slug}/blog?category=does-not-exist")
            ->assertInertia(fn (Assert $page) => $page->has('posts.data', 2)->where('filters.category', null));
        $this->get("/mosques/{$this->mosque->slug}/blog?category[]=x")->assertOk();
    }

    public function test_the_blog_search_matches_titles_and_text_and_escapes_wildcards(): void
    {
        $this->blogPost($this->mosque, ['title' => 'Cours de tajwid', 'body' => 'Le samedi.']);
        $this->blogPost($this->mosque, ['title' => 'Iftar', 'body' => 'Un repas partagé pour le TAJWID aussi.']);
        $this->blogPost($this->mosque, ['title' => 'Travaux', 'body' => 'Rien à voir.']);

        $this->get("/mosques/{$this->mosque->slug}/blog?q=tajwid")
            ->assertInertia(fn (Assert $page) => $page->has('posts.data', 2)->where('filters.q', 'tajwid'));
        $this->get("/mosques/{$this->mosque->slug}/blog?q=%25")
            ->assertInertia(fn (Assert $page) => $page->has('posts.data', 0));
        $this->get("/mosques/{$this->mosque->slug}/blog?q=".urlencode("\xC3\x28"))
            ->assertInertia(fn (Assert $page) => $page->has('posts.data', 3)->where('filters.q', ''));
    }

    public function test_the_blog_is_paginated(): void
    {
        foreach (range(1, 14) as $i) {
            $this->blogPost($this->mosque, ['published_at' => now()->subMinutes($i)]);
        }

        $this->get("/mosques/{$this->mosque->slug}/blog")
            ->assertInertia(fn (Assert $page) => $page->has('posts.data', 12)->where('posts.last_page', 2));
        $this->get("/mosques/{$this->mosque->slug}/blog?page=2")
            ->assertInertia(fn (Assert $page) => $page->has('posts.data', 2));
    }

    public function test_an_article_shows_its_markdown_video_and_pdf(): void
    {
        $category = $this->category($this->mosque, 'Khutbah', 'khutbah');
        $author = User::factory()->create(['name' => 'Imam Youssef']);
        $before = $this->blogPost($this->mosque, ['title' => 'Avant', 'published_at' => now()->subDays(3)]);
        $post = $this->blogPost($this->mosque, [
            'slug' => 'la-patience',
            'title' => 'La patience',
            'category_id' => $category->id,
            'author_id' => $author->id,
            'body' => "## Introduction\n\nLa **patience** est une lumière.",
            'video_url' => 'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
            'attachment_path' => "mosques/{$this->mosque->id}/files/la-patience-abc.pdf",
            'attachment_name' => 'La patience.pdf',
            'published_at' => now()->subDays(2),
        ]);
        $after = $this->blogPost($this->mosque, ['title' => 'Après', 'published_at' => now()->subDay()]);

        $this->get("/mosques/{$this->mosque->slug}/blog/la-patience")
            ->assertOk()
            ->assertInertia(fn (Assert $page) => $page
                ->component('mosques/post')
                ->where('post.id', $post->id)
                ->where('post.status', 'published')
                ->where('post.author', 'Imam Youssef')
                ->where('post.category.slug', 'khutbah')
                ->where('post.body_html', fn (string $html) => str_contains($html, '<h2>Introduction</h2>')
                    && str_contains($html, '<strong>patience</strong>'))
                ->where('post.video.provider', 'youtube')
                ->where('post.video.embed_url', 'https://www.youtube-nocookie.com/embed/dQw4w9WgXcQ?rel=0')
                ->where('post.attachment.name', 'La patience.pdf')
                ->where('neighbours.previous.title', $before->title)
                ->where('neighbours.next.title', $after->title)
                ->where('meta.type', 'article')
                ->where('shareUrl', route('mosques.blog.show', [$this->mosque, 'la-patience'])));
    }

    public function test_drafts_and_scheduled_articles_are_404_for_the_public_and_a_preview_for_managers(): void
    {
        $this->blogPost($this->mosque, ['slug' => 'brouillon', 'published_at' => null]);
        $this->blogPost($this->mosque, ['slug' => 'plus-tard', 'published_at' => now()->addDay()]);
        $stranger = User::factory()->create();
        $manager = $this->managerOf($this->mosque);

        foreach (['brouillon', 'plus-tard'] as $slug) {
            $this->get("/mosques/{$this->mosque->slug}/blog/{$slug}")->assertNotFound();
            $this->actingAs($stranger)->get("/mosques/{$this->mosque->slug}/blog/{$slug}")->assertNotFound();
        }

        $this->actingAs($manager)->get("/mosques/{$this->mosque->slug}/blog/brouillon")
            ->assertOk()
            ->assertInertia(fn (Assert $page) => $page->where('post.status', 'draft')->where('neighbours.previous', null));
        $this->actingAs($manager)->get("/mosques/{$this->mosque->slug}/blog/plus-tard")
            ->assertInertia(fn (Assert $page) => $page->where('post.status', 'scheduled'));
    }

    public function test_articles_belong_to_their_mosque_and_unknown_addresses_are_404(): void
    {
        $other = Mosque::factory()->create();
        $this->blogPost($other, ['slug' => 'ailleurs']);
        $deleted = $this->blogPost($this->mosque, ['slug' => 'supprime']);
        $deleted->delete();

        $this->get("/mosques/{$this->mosque->slug}/blog/ailleurs")->assertNotFound();
        $this->get("/mosques/{$this->mosque->slug}/blog/supprime")->assertNotFound();
        $this->get("/mosques/{$this->mosque->slug}/blog/Not_A_Slug")->assertNotFound();
        $this->get('/mosques/unknown-mosque/blog')->assertNotFound();
    }

    public function test_static_pages_are_public_once_published(): void
    {
        $this->sitePage($this->mosque, ['slug' => 'cours', 'title' => 'Nos cours', 'body' => "- Arabe\n- Coran"]);
        $this->sitePage($this->mosque, ['slug' => 'en-preparation', 'published_at' => null]);
        $manager = $this->managerOf($this->mosque);

        $this->get("/mosques/{$this->mosque->slug}/pages/cours")
            ->assertOk()
            ->assertInertia(fn (Assert $page) => $page
                ->component('mosques/page')
                ->where('page.title', 'Nos cours')
                ->where('page.published', true)
                ->where('page.body_html', fn (string $html) => str_contains($html, '<li>Arabe</li>'))
                ->where('meta.title', 'Nos cours · '.$this->mosque->name));

        $this->get("/mosques/{$this->mosque->slug}/pages/en-preparation")->assertNotFound();
        $this->get("/mosques/{$this->mosque->slug}/pages/nope")->assertNotFound();
        $this->actingAs($manager)->get("/mosques/{$this->mosque->slug}/pages/en-preparation")
            ->assertOk()
            ->assertInertia(fn (Assert $page) => $page->where('page.published', false)->where('canManage', true));
    }

    public function test_site_routes_never_capture_json_endpoints(): void
    {
        foreach (['/mosques/x/blog/feed.json', '/mosques/x/pages/a.json'] as $uri) {
            try {
                $route = Route::getRoutes()->match(Request::create($uri));
                $this->assertNotContains($route->getName(), ['mosques.blog.show', 'mosques.pages.show'], $uri);
            } catch (HttpException) {
                $this->addToAssertionCount(1);
            }
        }
    }
}
