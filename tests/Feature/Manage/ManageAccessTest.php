<?php

namespace Tests\Feature\Manage;

use App\Models\Mosque;
use App\Models\MosquePage;
use App\Models\MosquePost;
use App\Models\PostComment;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Inertia\Testing\AssertableInertia as Assert;
use Tests\TestCase;

class ManageAccessTest extends TestCase
{
    use RefreshDatabase;

    private Mosque $mosque;

    protected function setUp(): void
    {
        parent::setUp();
        $this->withoutVite();
        $this->mosque = Mosque::factory()->create();
    }

    /** @return list<string> */
    private function pages(): array
    {
        $slug = $this->mosque->slug;
        $post = MosquePost::factory()->for($this->mosque)->create();
        $page = MosquePage::query()->create([
            'mosque_id' => $this->mosque->id, 'title' => 'À propos', 'slug' => 'a-propos', 'body' => 'Bienvenue.',
        ]);

        return ["/manage/{$slug}", "/manage/{$slug}/details", "/manage/{$slug}/posts", "/manage/{$slug}/posts/create",
            "/manage/{$slug}/posts/{$post->id}/edit", "/manage/{$slug}/categories", "/manage/{$slug}/pages",
            "/manage/{$slug}/pages/create", "/manage/{$slug}/pages/{$page->id}/edit", "/manage/{$slug}/comments"];
    }

    public function test_guests_are_sent_to_the_login_page(): void
    {
        $this->get('/manage')->assertRedirect('/login');

        foreach ($this->pages() as $page) {
            $this->get($page)->assertRedirect('/login');
        }
    }

    public function test_people_who_do_not_manage_the_mosque_are_refused(): void
    {
        $user = User::factory()->create();
        Mosque::factory()->create()->managers()->attach($user, ['role' => 'owner']);   // manages another one

        foreach ($this->pages() as $page) {
            $this->actingAs($user)->get($page)->assertForbidden();
        }
        $this->actingAs($user)->put("/manage/{$this->mosque->slug}", ['description' => 'Hacked'])->assertForbidden();
        $this->actingAs($user)->post("/manage/{$this->mosque->slug}/posts", [
            'type' => 'news', 'title' => 'x', 'body' => 'y', 'publish' => true,
        ])->assertForbidden();
        $this->assertNull($this->mosque->fresh()->description);
        $this->assertDatabaseCount('mosque_posts', 1);
    }

    public function test_managers_open_every_management_page(): void
    {
        $manager = User::factory()->create();
        $this->mosque->managers()->attach($manager, ['role' => 'owner']);

        foreach ($this->pages() as $page) {
            $this->actingAs($manager)->get($page)->assertOk();
        }

        $this->actingAs($manager)->get("/manage/{$this->mosque->slug}")
            ->assertInertia(fn (Assert $page) => $page
                ->component('manage/overview')
                ->where('mosque.slug', $this->mosque->slug)
                ->has('stats')
                ->has('checklist'));

        $this->actingAs($manager)->get("/manage/{$this->mosque->slug}/details")
            ->assertInertia(fn (Assert $page) => $page
                ->component('manage/edit')
                ->where('mosque.slug', $this->mosque->slug)
                ->has('values.description')
                ->has('values.social_links.facebook')
                ->has('palette'));
    }

    public function test_admins_manage_any_mosque(): void
    {
        $admin = User::factory()->create();
        $admin->forceFill(['is_admin' => true])->save();

        foreach ($this->pages() as $page) {
            $this->actingAs($admin)->get($page)->assertOk();
        }
    }

    public function test_managers_need_a_verified_email(): void
    {
        $manager = User::factory()->unverified()->create();
        $this->mosque->managers()->attach($manager, ['role' => 'owner']);

        $this->actingAs($manager)->get("/manage/{$this->mosque->slug}")->assertRedirect('/email/verify');
    }

    public function test_the_index_lists_the_mosques_i_manage(): void
    {
        $manager = User::factory()->create();
        $this->mosque->managers()->attach($manager, ['role' => 'editor']);
        Mosque::factory()->create();   // not mine
        MosquePost::factory()->for($this->mosque)->create();
        $draft = MosquePost::factory()->for($this->mosque)->create(['published_at' => null]);
        PostComment::factory()->count(2)->for($draft, 'post')->create();

        $this->actingAs($manager)->get('/manage')
            ->assertOk()
            ->assertInertia(fn (Assert $page) => $page
                ->component('manage/index')
                ->has('mosques', 1)
                ->where('mosques.0.slug', $this->mosque->slug)
                ->where('mosques.0.role', 'editor')
                ->where('mosques.0.published_count', 1)
                ->where('mosques.0.drafts_count', 1)
                ->where('mosques.0.comments_count', 2)
                ->where('isAdmin', false));
    }

    public function test_the_moderation_list_shows_hidden_comments_and_filters_them(): void
    {
        $manager = User::factory()->create();
        $this->mosque->managers()->attach($manager, ['role' => 'owner']);
        $post = MosquePost::factory()->for($this->mosque)->create();
        PostComment::factory()->for($post, 'post')->create();
        $hidden = PostComment::factory()->for($post, 'post')->create(['hidden_at' => now()]);
        PostComment::factory()->create();   // another mosque's comment

        $this->actingAs($manager)->get("/manage/{$this->mosque->slug}/comments")
            ->assertInertia(fn (Assert $page) => $page
                ->component('manage/comments')
                ->has('comments.data', 2)
                ->where('filter', 'all'));

        $this->actingAs($manager)->get("/manage/{$this->mosque->slug}/comments?filter=hidden")
            ->assertInertia(fn (Assert $page) => $page
                ->has('comments.data', 1)
                ->where('comments.data.0.id', $hidden->id)
                ->where('comments.data.0.hidden', true)
                ->where('comments.data.0.post.title', $post->title));
    }
}
