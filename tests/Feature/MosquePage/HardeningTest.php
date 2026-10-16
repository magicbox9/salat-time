<?php

namespace Tests\Feature\MosquePage;

use App\Models\Mosque;
use App\Models\MosquePost;
use App\Models\PostComment;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Pagination\Cursor;
use Illuminate\Support\Facades\DB;
use Inertia\Testing\AssertableInertia as Assert;
use PHPUnit\Framework\Attributes\DataProvider;
use Tests\TestCase;

/** Visitor-controlled input that must end in a clean 4xx, never a database error. */
class HardeningTest extends TestCase
{
    use RefreshDatabase;

    private const HUGE_ID = '99999999999999999999';   // beyond PostgreSQL's bigint

    private Mosque $mosque;

    private MosquePost $post;

    protected function setUp(): void
    {
        parent::setUp();
        $this->withoutVite();
        $this->mosque = Mosque::factory()->create();
        $this->post = MosquePost::factory()->for($this->mosque)->create(['published_at' => now()->subHour()]);
    }

    /** @param  array<string, mixed>  $parameters */
    private static function cursor(array $parameters, mixed $next = true): string
    {
        return str_replace(['+', '/', '='], ['-', '_', ''], base64_encode((string) json_encode(
            [...$parameters, '_pointsToNextItems' => $next],
        )));
    }

    /** @return array<string, array{0: string}> */
    public static function forgedFeedCursors(): array
    {
        return [
            'not a timestamp' => [self::cursor(['published_at' => 'yesterday-ish', 'id' => 1])],
            'not an id' => [self::cursor(['published_at' => '2026-01-01 10:00:00', 'id' => 'abc'])],
            'id beyond bigint' => [self::cursor(['published_at' => '2026-01-01 10:00:00', 'id' => 1e30])],
            'missing column' => [self::cursor(['id' => 4])],
            'unknown column' => [self::cursor(['published_at' => '2026-01-01 10:00:00', 'id' => 4, 'title' => 'x'])],
            'odd direction' => [self::cursor(['published_at' => '2026-01-01 10:00:00', 'id' => 4], 'yes')],
            'not a cursor at all' => ['%%%not-base64%%%'],
        ];
    }

    #[DataProvider('forgedFeedCursors')]
    public function test_forged_feed_cursors_are_refused(string $cursor): void
    {
        $this->getJson("/mosques/{$this->mosque->slug}/posts.json?cursor=".urlencode($cursor))
            ->assertUnprocessable()
            ->assertJsonValidationErrors('cursor');
    }

    public function test_a_genuine_feed_cursor_still_works(): void
    {
        $cursor = (new Cursor(['published_at' => now()->toDateTimeString(), 'id' => PHP_INT_MAX]))->encode();

        $this->getJson("/mosques/{$this->mosque->slug}/posts.json?cursor=".urlencode($cursor))
            ->assertOk()
            ->assertJsonPath('data.0.id', $this->post->id);
    }

    public function test_forged_comment_cursors_are_refused(): void
    {
        PostComment::factory()->count(3)->for($this->post, 'post')->create();
        $url = "/mosques/{$this->mosque->slug}/posts/{$this->post->id}/comments";

        foreach ([self::cursor(['id' => 'abc']), self::cursor(['id' => -3]), self::cursor(['created_at' => 'x'])] as $cursor) {
            $this->getJson($url.'?cursor='.urlencode($cursor))
                ->assertUnprocessable()
                ->assertJsonValidationErrors('cursor');
        }

        $this->getJson($url.'?cursor='.urlencode(self::cursor(['id' => 1])))->assertOk();
    }

    public function test_ids_beyond_bigint_are_simply_not_found(): void
    {
        $manager = User::factory()->create();
        $this->mosque->managers()->attach($manager, ['role' => 'owner']);
        $slug = $this->mosque->slug;

        $this->getJson("/mosques/{$slug}/posts/".self::HUGE_ID.'/comments')->assertNotFound();
        $this->actingAs($manager)->postJson("/mosques/{$slug}/posts/".self::HUGE_ID.'/comments', ['body' => 'Salam'])
            ->assertNotFound();
        $this->deleteJson('/comments/'.self::HUGE_ID)->assertNotFound();
        $this->patchJson('/comments/'.self::HUGE_ID.'/hide')->assertNotFound();
        $this->get("/manage/{$slug}/posts/".self::HUGE_ID.'/edit')->assertNotFound();
        $this->delete("/manage/{$slug}/posts/".self::HUGE_ID)->assertNotFound();
    }

    public function test_reloading_only_the_viewer_skips_the_feed_and_the_times(): void
    {
        $user = User::factory()->create();
        $user->favoriteMosques()->attach($this->mosque);
        $response = $this->actingAs($user)->get("/mosques/{$this->mosque->slug}")->assertOk();

        DB::flushQueryLog();
        DB::enableQueryLog();
        $response->assertInertia(fn (Assert $page) => $page->reloadOnly('viewer', fn (Assert $reload) => $reload
            ->where('viewer.favorite', true)
            ->missing('feed')
            ->missing('live')));
        $queries = collect(DB::getQueryLog())->pluck('query')->implode("\n");
        DB::disableQueryLog();

        $this->assertStringContainsString('favorite_mosques', $queries);
        $this->assertStringNotContainsString('mosque_posts', $queries);
        $this->assertStringNotContainsString('mosque_prayer_calendars', $queries);
    }

    public function test_text_that_is_not_clean_utf8_is_refused_not_crashing(): void
    {
        $user = User::factory()->create();
        $this->mosque->managers()->attach($user, ['role' => 'owner']);
        $comments = "/mosques/{$this->mosque->slug}/posts/{$this->post->id}/comments";
        $invalidUtf8 = "Salam \xC3\x28 alaykum";

        $this->actingAs($user)->from("/mosques/{$this->mosque->slug}")
            ->post($comments, ['body' => $invalidUtf8])
            ->assertSessionHasErrors('body');
        $this->postJson($comments, ['body' => "Salam\0alaykum"])->assertJsonValidationErrors('body');

        $this->post("/manage/{$this->mosque->slug}/posts", [
            'type' => 'news', 'title' => $invalidUtf8, 'body' => $invalidUtf8, 'publish' => true,
        ])->assertSessionHasErrors(['title', 'body']);
        $this->put("/manage/{$this->mosque->slug}", ['description' => $invalidUtf8])
            ->assertSessionHasErrors('description');

        $this->assertDatabaseCount('post_comments', 0);
        $this->assertDatabaseCount('mosque_posts', 1);
    }
}
