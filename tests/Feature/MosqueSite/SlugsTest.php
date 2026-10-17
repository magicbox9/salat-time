<?php

namespace Tests\Feature\MosqueSite;

use App\Http\Controllers\MosquePage\Support\Slugs;
use App\Models\Mosque;
use App\Models\MosquePost;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Tests\TestCase;

/** Every post gets a readable address, unique within its mosque. */
class SlugsTest extends TestCase
{
    use BuildsMosqueSites, RefreshDatabase;

    public function test_the_backfill_migration_gives_unique_slugs_per_mosque(): void
    {
        $mosque = Mosque::factory()->create();
        $other = Mosque::factory()->create();
        $taken = $this->blogPost($mosque, ['slug' => 'cours-de-tajwid', 'title' => 'Ancien']);
        $a = MosquePost::factory()->for($mosque)->create(['title' => 'Cours de tajwid', 'slug' => null]);
        $b = MosquePost::factory()->for($mosque)->create(['title' => 'Cours de tajwid !', 'slug' => null]);
        $c = MosquePost::factory()->for($other)->create(['title' => 'Cours de tajwid', 'slug' => null]);
        $arabic = MosquePost::factory()->for($mosque)->create(['title' => 'خطبة الجمعة', 'slug' => null]);
        $symbols = MosquePost::factory()->for($mosque)->create(['title' => '!!!', 'slug' => null]);
        $trashed = MosquePost::factory()->for($mosque)->create(['title' => 'Supprimé', 'slug' => null]);
        $trashed->delete();

        $migration = require database_path('migrations/2026_10_18_200001_backfill_mosque_post_slugs.php');
        $migration->up();

        $this->assertSame('cours-de-tajwid', $taken->fresh()->slug);
        $this->assertSame('cours-de-tajwid-2', $a->fresh()->slug);
        $this->assertSame('cours-de-tajwid-3', $b->fresh()->slug);
        $this->assertSame('cours-de-tajwid', $c->fresh()->slug);
        $this->assertMatchesRegularExpression('/^'.Slugs::PATTERN.'$/', $arabic->fresh()->slug);
        $this->assertSame('post', $symbols->fresh()->slug);
        $this->assertNull(MosquePost::withTrashed()->find($trashed->id)->slug);

        // Running it again changes nothing.
        $before = DB::table('mosque_posts')->orderBy('id')->pluck('slug', 'id')->all();
        $migration->up();
        $this->assertSame($before, DB::table('mosque_posts')->orderBy('id')->pluck('slug', 'id')->all());
    }

    public function test_unique_slugs_count_soft_deleted_rows_and_respect_the_length(): void
    {
        $mosque = Mosque::factory()->create();
        $gone = $this->blogPost($mosque, ['slug' => 'iftar']);
        $gone->delete();

        $this->assertSame('iftar-2', Slugs::unique('mosque_posts', $mosque->id, 'iftar', null, Slugs::POST_MAX));
        $this->assertSame('iftar', Slugs::unique('mosque_posts', $mosque->id, 'iftar', $gone->id, Slugs::POST_MAX));

        $long = str_repeat('a', 200);
        $this->blogPost($mosque, ['slug' => $long]);
        $next = Slugs::unique('mosque_posts', $mosque->id, $long, null, Slugs::POST_MAX);
        $this->assertSame(200, strlen($next));
        $this->assertStringEndsWith('-2', $next);
    }

    public function test_a_retired_slug_can_never_match_a_live_one(): void
    {
        $retired = Slugs::retired(str_repeat('b', 220), 42, Slugs::POST_MAX);

        $this->assertLessThanOrEqual(Slugs::POST_MAX, strlen($retired));
        $this->assertStringEndsWith('.deleted.42', $retired);
        $this->assertDoesNotMatchRegularExpression('/^'.Slugs::PATTERN.'$/', $retired);
    }
}
