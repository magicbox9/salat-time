<?php

namespace Tests\Feature\Manage;

use App\Models\Mosque;
use App\Models\MosquePost;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Gate;
use Illuminate\Support\Facades\Storage;
use Inertia\Testing\AssertableInertia as Assert;
use Tests\TestCase;

class PostManagementTest extends TestCase
{
    use RefreshDatabase;

    private Mosque $mosque;

    private User $manager;

    protected function setUp(): void
    {
        parent::setUp();
        $this->withoutVite();
        Storage::fake('public');
        $this->mosque = Mosque::factory()->create(['timezone' => 'Europe/Paris']);
        $this->manager = User::factory()->create();
        $this->mosque->managers()->attach($this->manager, ['role' => 'owner']);
    }

    private function base(): string
    {
        return "/manage/{$this->mosque->slug}/posts";
    }

    /** @return array<string, mixed> */
    private function valid(array $overrides = []): array
    {
        return [
            'type' => 'news',
            'title' => 'Cours de tajwid',
            'body' => "Reprise des cours samedi.\nInscriptions sur https://example.org",
            'pinned' => false,
            'publish' => true,
            ...$overrides,
        ];
    }

    public function test_managers_publish_a_post_that_appears_on_the_page(): void
    {
        $this->actingAs($this->manager)->post($this->base(), $this->valid())
            ->assertRedirect($this->base())
            ->assertSessionHasNoErrors();

        $post = MosquePost::query()->sole();
        $this->assertSame($this->mosque->id, $post->mosque_id);
        $this->assertSame($this->manager->id, $post->author_id);
        $this->assertNotNull($post->published_at);

        $this->get("/mosques/{$this->mosque->slug}")
            ->assertInertia(fn (Assert $page) => $page->where('feed.data.0.title', 'Cours de tajwid'));
    }

    public function test_drafts_stay_private_until_published(): void
    {
        $this->actingAs($this->manager)->post($this->base(), $this->valid(['publish' => false]));
        $post = MosquePost::query()->sole();
        $this->assertNull($post->published_at);

        $this->app['auth']->forgetGuards();
        $this->get("/mosques/{$this->mosque->slug}")
            ->assertInertia(fn (Assert $page) => $page->has('feed.data', 0)->has('pinned', 0));

        $this->actingAs($this->manager)->get($this->base().'?status=drafts')
            ->assertInertia(fn (Assert $page) => $page->component('manage/posts')->has('posts.data', 1));

        $this->actingAs($this->manager)->put("{$this->base()}/{$post->id}", $this->valid(['publish' => true]))
            ->assertSessionHasNoErrors();
        $this->assertNotNull($post->fresh()->published_at);

        $this->actingAs($this->manager)->put("{$this->base()}/{$post->id}", $this->valid(['publish' => false]));
        $this->assertNull($post->fresh()->published_at);
    }

    public function test_events_need_a_start_stored_in_utc(): void
    {
        $this->actingAs($this->manager)->post($this->base(), $this->valid(['type' => 'event']))
            ->assertSessionHasErrors('event_starts_at');

        $this->actingAs($this->manager)
            ->post($this->base(), $this->valid(['type' => 'event', 'event_starts_at' => '2026-11-20T19:30']))
            ->assertSessionHasNoErrors();

        $post = MosquePost::query()->sole();
        $this->assertSame('2026-11-20 18:30:00', $post->event_starts_at->utc()->format('Y-m-d H:i:s'));

        $this->actingAs($this->manager)->get("{$this->base()}/{$post->id}/edit")
            ->assertInertia(fn (Assert $page) => $page
                ->component('manage/post-form')
                ->where('post.event_starts_at', '2026-11-20T19:30'));
    }

    public function test_posts_are_validated(): void
    {
        $this->actingAs($this->manager)->post($this->base(), [
            'type' => 'advert',
            'title' => str_repeat('t', 201),
            'body' => str_repeat('b', 10001),
            'image' => UploadedFile::fake()->create('notes.txt', 3, 'text/plain'),
        ])->assertSessionHasErrors(['type', 'title', 'body', 'image']);

        $this->actingAs($this->manager)->post($this->base(), $this->valid(['title' => '', 'body' => '']))
            ->assertSessionHasErrors(['title', 'body']);

        $this->assertDatabaseCount('mosque_posts', 0);
    }

    public function test_images_are_stored_replaced_and_removed(): void
    {
        $this->actingAs($this->manager)
            ->post($this->base(), $this->valid(['image' => UploadedFile::fake()->image('iftar.jpg', 2400, 1600)]))
            ->assertSessionHasNoErrors();

        $post = MosquePost::query()->sole();
        $first = $post->image_path;
        $this->assertStringStartsWith("mosques/{$this->mosque->id}/posts/", $first);
        Storage::disk('public')->assertExists($first);

        $this->actingAs($this->manager)->put("{$this->base()}/{$post->id}", $this->valid([
            'image' => UploadedFile::fake()->image('new.png', 400, 300),
        ]))->assertSessionHasNoErrors();
        Storage::disk('public')->assertMissing($first);
        Storage::disk('public')->assertExists($post->fresh()->image_path);

        $second = $post->fresh()->image_path;
        $this->actingAs($this->manager)->put("{$this->base()}/{$post->id}", $this->valid(['remove_image' => true]));
        $this->assertNull($post->fresh()->image_path);
        Storage::disk('public')->assertMissing($second);
    }

    public function test_managers_delete_posts(): void
    {
        $post = MosquePost::factory()->for($this->mosque)->create();

        $this->actingAs($this->manager)->delete("{$this->base()}/{$post->id}")->assertRedirect($this->base());
        $this->assertSoftDeleted($post);

        $this->get("/mosques/{$this->mosque->slug}")
            ->assertInertia(fn (Assert $page) => $page->has('feed.data', 0));
    }

    public function test_posts_of_another_mosque_cannot_be_reached_through_this_one(): void
    {
        $foreign = MosquePost::factory()->create(['title' => 'Not yours']);

        $this->actingAs($this->manager)->get("{$this->base()}/{$foreign->id}/edit")->assertNotFound();
        $this->actingAs($this->manager)->put("{$this->base()}/{$foreign->id}", $this->valid())->assertNotFound();
        $this->actingAs($this->manager)->delete("{$this->base()}/{$foreign->id}")->assertNotFound();

        $this->assertSame('Not yours', $foreign->fresh()->title);
        $this->assertNotSoftDeleted($foreign);
    }

    public function test_admins_can_post_on_any_mosque(): void
    {
        $admin = User::factory()->create();
        $admin->forceFill(['is_admin' => true])->save();

        $this->actingAs($admin)->post($this->base(), $this->valid(['type' => 'janaza', 'pinned' => true]))
            ->assertSessionHasNoErrors();

        $post = MosquePost::query()->sole();
        $this->assertSame('janaza', $post->type);
        $this->assertTrue($post->pinned);
    }

    public function test_the_post_policy_follows_the_post_s_own_mosque(): void
    {
        $own = MosquePost::factory()->for($this->mosque)->create();
        $foreign = MosquePost::factory()->create();
        $gate = Gate::forUser($this->manager);

        $this->assertTrue($gate->allows('update', $own));
        $this->assertTrue($gate->allows('delete', $own));
        $this->assertFalse($gate->allows('update', $foreign));
        $this->assertFalse($gate->allows('delete', $foreign));
    }
}
