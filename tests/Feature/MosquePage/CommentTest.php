<?php

namespace Tests\Feature\MosquePage;

use App\Models\Mosque;
use App\Models\MosquePost;
use App\Models\PostComment;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class CommentTest extends TestCase
{
    use RefreshDatabase;

    private Mosque $mosque;

    private MosquePost $post;

    protected function setUp(): void
    {
        parent::setUp();
        $this->withoutVite();
        $this->mosque = Mosque::factory()->create();
        $this->post = MosquePost::factory()->for($this->mosque)->create(['published_at' => now()->subHour()]);
    }

    private function url(?MosquePost $post = null): string
    {
        $post ??= $this->post;

        return "/mosques/{$post->mosque->slug}/posts/{$post->id}/comments";
    }

    private function manager(): User
    {
        $manager = User::factory()->create();
        $this->mosque->managers()->attach($manager, ['role' => 'owner']);

        return $manager;
    }

    public function test_guests_cannot_comment(): void
    {
        $this->postJson($this->url(), ['body' => 'Salam alaykum'])->assertUnauthorized();
        $this->assertDatabaseCount('post_comments', 0);
    }

    public function test_unverified_users_cannot_comment(): void
    {
        $this->actingAs(User::factory()->unverified()->create())
            ->postJson($this->url(), ['body' => 'Salam alaykum'])
            ->assertForbidden();
        $this->assertDatabaseCount('post_comments', 0);
    }

    public function test_verified_users_can_comment(): void
    {
        $user = User::factory()->create(['name' => 'Amina']);

        $this->actingAs($user)
            ->postJson($this->url(), ['body' => "  Barak Allahu fikum\nfor the lesson  "])
            ->assertCreated()
            ->assertJsonPath('comment.body', "Barak Allahu fikum\nfor the lesson")
            ->assertJsonPath('comment.author', 'Amina')
            ->assertJsonPath('comment.mine', true)
            ->assertJsonPath('comment.can_delete', true)
            ->assertJsonPath('comment.can_moderate', false);

        $this->assertDatabaseHas('post_comments', ['post_id' => $this->post->id, 'user_id' => $user->id]);
    }

    public function test_comments_are_validated(): void
    {
        $user = User::factory()->create();

        $this->actingAs($user)->postJson($this->url(), ['body' => 'a'])->assertJsonValidationErrors('body');
        $this->actingAs($user)->postJson($this->url(), ['body' => str_repeat('a', 1001)])->assertJsonValidationErrors('body');
        $this->actingAs($user)->postJson($this->url(), [])->assertJsonValidationErrors('body');
        $this->assertDatabaseCount('post_comments', 0);
    }

    public function test_drafts_and_other_mosques_posts_cannot_be_commented(): void
    {
        $user = User::factory()->create();
        $draft = MosquePost::factory()->for($this->mosque)->create(['published_at' => null]);
        $foreign = MosquePost::factory()->create();

        $this->actingAs($user)->postJson($this->url($draft), ['body' => 'Hello'])->assertNotFound();
        $this->actingAs($user)
            ->postJson("/mosques/{$this->mosque->slug}/posts/{$foreign->id}/comments", ['body' => 'Hello'])
            ->assertNotFound();
        $this->getJson($this->url($draft))->assertNotFound();
    }

    public function test_commenting_is_throttled(): void
    {
        $user = User::factory()->create();

        foreach (range(1, 5) as $i) {
            $this->actingAs($user)->postJson($this->url(), ['body' => "Comment {$i}"])->assertCreated();
        }

        $this->actingAs($user)->postJson($this->url(), ['body' => 'One too many'])->assertTooManyRequests();
        $this->assertDatabaseCount('post_comments', 5);
    }

    public function test_authors_delete_their_own_comments_only(): void
    {
        $author = User::factory()->create();
        $comment = PostComment::factory()->for($this->post, 'post')->for($author)->create();
        $other = User::factory()->create();

        $this->actingAs($other)->deleteJson("/comments/{$comment->id}")->assertForbidden();
        $this->assertNotSoftDeleted($comment);

        $this->actingAs($author)->deleteJson("/comments/{$comment->id}")->assertOk();
        $this->assertSoftDeleted($comment);
    }

    public function test_managers_hide_and_restore_comments(): void
    {
        $comment = PostComment::factory()->for($this->post, 'post')->create();
        $manager = $this->manager();

        $this->actingAs($manager)
            ->patchJson("/comments/{$comment->id}/hide")
            ->assertOk()
            ->assertJsonPath('comment.hidden', true);
        $this->assertNotNull($comment->fresh()->hidden_at);
        $this->assertSame($manager->id, $comment->fresh()->hidden_by);

        // Hidden for the public, shown (and marked) for the managers.
        $this->app['auth']->forgetGuards();
        $this->getJson($this->url())->assertOk()->assertJsonCount(0, 'data');
        $this->actingAs($manager)->getJson($this->url())
            ->assertJsonCount(1, 'data')
            ->assertJsonPath('data.0.hidden', true)
            ->assertJsonPath('data.0.can_moderate', true);

        $this->actingAs($manager)->patchJson("/comments/{$comment->id}/unhide")->assertOk();
        $this->assertNull($comment->fresh()->hidden_at);
    }

    public function test_others_cannot_hide_comments(): void
    {
        $comment = PostComment::factory()->for($this->post, 'post')->create();
        $managerElsewhere = User::factory()->create();
        Mosque::factory()->create()->managers()->attach($managerElsewhere, ['role' => 'owner']);

        $this->patchJson("/comments/{$comment->id}/hide")->assertUnauthorized();
        $this->actingAs($comment->user)->patchJson("/comments/{$comment->id}/hide")->assertForbidden();
        $this->actingAs($managerElsewhere)->patchJson("/comments/{$comment->id}/hide")->assertForbidden();
        $this->assertNull($comment->fresh()->hidden_at);
    }

    public function test_admins_moderate_any_comment(): void
    {
        $comment = PostComment::factory()->for($this->post, 'post')->create();
        $admin = User::factory()->create();
        $admin->forceFill(['is_admin' => true])->save();

        $this->actingAs($admin)->patchJson("/comments/{$comment->id}/hide")->assertOk();
        $this->actingAs($admin)->deleteJson("/comments/{$comment->id}")->assertOk();
        $this->assertSoftDeleted($comment);
    }

    public function test_moderation_from_the_management_area_redirects_back(): void
    {
        $comment = PostComment::factory()->for($this->post, 'post')->create();
        $manager = $this->manager();
        $from = "/manage/{$this->mosque->slug}/comments";

        $this->actingAs($manager)->from($from)->patch("/comments/{$comment->id}/hide")->assertRedirect($from);
        $this->assertNotNull($comment->fresh()->hidden_at);
    }

    public function test_the_comment_list_is_public_and_paginated(): void
    {
        PostComment::factory()->count(22)->for($this->post, 'post')->create();

        $first = $this->getJson($this->url())->assertOk()->assertJsonCount(20, 'data');
        $this->assertFalse($first->json('data.0.can_delete'));
        $this->assertFalse($first->json('data.0.can_moderate'));

        $this->getJson($this->url().'?cursor='.urlencode($first->json('next_cursor')))
            ->assertOk()
            ->assertJsonCount(2, 'data')
            ->assertJsonPath('next_cursor', null);
    }
}
