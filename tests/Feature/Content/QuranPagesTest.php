<?php

namespace Tests\Feature\Content;

use App\Models\QuranBookmark;
use App\Models\User;
use App\Services\Content\QuranCorpus;
use Illuminate\Cache\Events\CacheHit;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Event;
use Inertia\Testing\AssertableInertia as Assert;
use Tests\TestCase;

class QuranPagesTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        // The pages are checked as Inertia responses; no built assets needed.
        $this->withoutVite();
    }

    public function test_the_index_lists_the_114_surahs(): void
    {
        $this->get('/quran')
            ->assertOk()
            ->assertInertia(fn (Assert $page) => $page
                ->component('quran/index')
                ->has('surahs', 114)
                ->where('surahs.0.number', 1)
                ->where('surahs.0.ayah_count', 7)
                ->where('surahs.1.name_en', 'Al-Baqarah')
                ->where('surahs.1.end_page', 49)
                ->where('surahs.113.number', 114)
                ->where('bookmarks', [])
                ->where('continue', null));
    }

    public function test_the_reader_passes_only_the_surahs_ayat(): void
    {
        foreach ([1 => 7, 2 => 286, 9 => 129, 114 => 6] as $surah => $count) {
            $this->get("/quran/$surah")
                ->assertOk()
                ->assertInertia(fn (Assert $page) => $page
                    ->component('quran/show')
                    ->where('surah.number', $surah)
                    ->where('surah.ayah_count', $count)
                    ->has('ayat', $count)
                    ->where('ayat.0.ayah', 1)
                    ->has('reciters', 4));
        }
    }

    public function test_the_basmala_heads_every_surah_but_al_fatiha_and_at_tawbah(): void
    {
        $this->get('/quran/1')->assertInertia(fn (Assert $page) => $page->where('basmala', null)->where('previous', null));
        $this->get('/quran/9')->assertInertia(fn (Assert $page) => $page->where('basmala', null));
        $this->get('/quran/2')->assertInertia(fn (Assert $page) => $page
            ->where('basmala', app(QuranCorpus::class)->basmala())
            ->where('previous.number', 1)
            ->where('next.number', 3));
        $this->get('/quran/114')->assertInertia(fn (Assert $page) => $page->where('next', null));
    }

    public function test_an_invalid_surah_is_not_found(): void
    {
        foreach (['/quran/0', '/quran/115', '/quran/999', '/quran/9999', '/quran/abc', '/quran/-1'] as $url) {
            $this->get($url)->assertNotFound();
        }
    }

    public function test_a_surah_has_one_canonical_url(): void
    {
        foreach (['/quran/007', '/quran/01', '/quran/000'] as $url) {
            $this->get($url)->assertNotFound();
        }
        $this->get('/quran/7')->assertOk();
    }

    public function test_surah_names_are_read_from_the_cache_once_per_request(): void
    {
        $user = User::factory()->create();
        foreach (range(1, 40) as $surah) {
            QuranBookmark::create(['user_id' => $user->id, 'surah' => $surah, 'ayah' => 1]);
        }
        app(QuranCorpus::class)->surahs(); // warm the cache

        Event::fake([CacheHit::class]);
        $this->actingAs($user)->get('/quran')->assertOk()->assertInertia(fn (Assert $page) => $page
            ->has('bookmarks', 40)
            ->where('bookmarks.39.name_en', 'Al-Fātiḥah'));

        $hits = collect(Event::dispatched(CacheHit::class))
            ->filter(fn (array $event) => str_ends_with($event[0]->key, ':index'));
        $this->assertCount(1, $hits, 'the surah index is memoised for the request');
    }

    public function test_the_translation_follows_the_language_and_the_choice(): void
    {
        // English interface: the English translation of the meanings.
        $this->get('/quran/1')->assertInertia(fn (Assert $page) => $page
            ->where('translationCode', 'en')
            ->where('translation.code', 'en')
            ->where('translation.version', '1.0.19')
            ->has('translation.ayat', 7)
            ->where('translation.ayat.1.text', 'In the name of Allah, the Most Compassionate, the Most Merciful.'));

        // An explicit choice wins, and is remembered for the session.
        $this->get('/quran/1?tr=fr')->assertInertia(fn (Assert $page) => $page
            ->where('translationCode', 'fr')
            ->where('translation.code', 'fr')
            ->has('translation.ayat', 7));
        $this->get('/quran/2')->assertInertia(fn (Assert $page) => $page
            ->where('translationCode', 'fr')
            ->has('translation.ayat', 286));

        $this->get('/quran/1?tr=none')->assertInertia(fn (Assert $page) => $page
            ->where('translationCode', 'none')
            ->where('translation', null));

        // Unknown values are ignored.
        $this->get('/quran/1?tr=xx')->assertInertia(fn (Assert $page) => $page->where('translationCode', 'none'));
    }

    public function test_the_index_shows_a_readers_bookmarks_and_where_to_continue(): void
    {
        $user = User::factory()->create();
        $other = User::factory()->create();
        QuranBookmark::create(['user_id' => $other->id, 'surah' => 3, 'ayah' => 1]);
        $older = QuranBookmark::create(['user_id' => $user->id, 'surah' => 18, 'ayah' => 10, 'note' => 'Friday']);
        $older->forceFill(['updated_at' => now()->subDay()])->save();
        QuranBookmark::create(['user_id' => $user->id, 'surah' => 2, 'ayah' => 255]);

        $this->actingAs($user)->get('/quran')->assertInertia(fn (Assert $page) => $page
            ->has('bookmarks', 2)
            ->where('continue.surah', 2)
            ->where('continue.ayah', 255)
            ->where('continue.name_en', 'Al-Baqarah')
            ->where('bookmarks.1.note', 'Friday'));
    }

    public function test_the_reader_lists_only_the_readers_bookmarks_in_this_surah(): void
    {
        $user = User::factory()->create();
        QuranBookmark::create(['user_id' => $user->id, 'surah' => 2, 'ayah' => 255]);
        QuranBookmark::create(['user_id' => $user->id, 'surah' => 3, 'ayah' => 1]);
        QuranBookmark::create(['user_id' => User::factory()->create()->id, 'surah' => 2, 'ayah' => 1]);

        $this->get('/quran/2')->assertInertia(fn (Assert $page) => $page->where('bookmarks', []));

        $this->actingAs($user)->get('/quran/2')->assertInertia(fn (Assert $page) => $page
            ->has('bookmarks', 1)
            ->where('bookmarks.0.ayah', 255));
    }
}
