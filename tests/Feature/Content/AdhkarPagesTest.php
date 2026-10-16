<?php

namespace Tests\Feature\Content;

use App\Services\Content\AdhkarLibrary;
use Inertia\Testing\AssertableInertia as Assert;
use Tests\TestCase;

class AdhkarPagesTest extends TestCase
{
    protected function setUp(): void
    {
        parent::setUp();
        $this->withoutVite();
    }

    public function test_the_index_lists_every_category_with_its_count(): void
    {
        $this->get('/adhkar')
            ->assertOk()
            ->assertInertia(fn (Assert $page) => $page
                ->component('adhkar/index')
                ->has('categories', 14)
                ->where('categories.0.key', 'morning')
                ->where('categories.0.count', 25)
                ->where('categories.0.name_ar', 'أذكار الصباح')
                ->where('categories.1.key', 'evening')
                ->where('categories.1.count', 23)
                ->where('categories.13.key', 'forgiveness'));
    }

    public function test_a_category_shows_its_adhkar(): void
    {
        $this->get('/adhkar/morning')
            ->assertOk()
            ->assertInertia(fn (Assert $page) => $page
                ->component('adhkar/show')
                ->where('category.key', 'morning')
                ->has('items', 25)
                ->where('items.1.count', 3)
                ->where('items.1.audio.url', 'https://server8.mp3quran.net/afs/112.mp3')
                ->where('items.0.audio.url', 'https://www.hisnmuslim.com/audio/ar/75.mp3')
                ->has('related', 13));

        $this->get('/adhkar/entering_mosque')
            ->assertOk()
            ->assertInertia(fn (Assert $page) => $page->has('items', 1));
    }

    public function test_an_unknown_category_is_not_found(): void
    {
        foreach (['/adhkar/nope', '/adhkar/_meta', '/adhkar/MORNING', '/adhkar/morning.json'] as $url) {
            $this->get($url)->assertNotFound();
        }
    }

    public function test_items_label_english_meanings_and_arabic_virtues_apart(): void
    {
        $library = app(AdhkarLibrary::class);
        $morning = $library->items('morning');
        $sleep = $library->items('sleep');

        $this->assertNotNull($morning[0]['virtue']);
        $this->assertNull($morning[0]['meaning_en']);
        $this->assertNull($sleep[0]['virtue']);
        $this->assertStringStartsWith('(When retiring', (string) $sleep[0]['meaning_en']);
    }

    public function test_audio_only_points_at_the_two_publishers_over_https(): void
    {
        $library = app(AdhkarLibrary::class);

        foreach (AdhkarLibrary::CATEGORIES as $category) {
            foreach ($library->items($category) as $item) {
                $this->assertNotSame('', trim($item['arabic']));
                $this->assertGreaterThanOrEqual(1, $item['count']);
                if ($item['audio'] !== null) {
                    $this->assertMatchesRegularExpression(
                        '#^https://(www\.hisnmuslim\.com/audio/ar|server8\.mp3quran\.net/afs)/\d{1,4}\.mp3$#',
                        $item['audio']['url'],
                    );
                }
            }
        }
    }

    public function test_only_the_morning_and_evening_quls_use_the_quran_recitation(): void
    {
        $this->assertSame('https://server8.mp3quran.net/afs/112.mp3', AdhkarLibrary::audio('morning', '112.mp3')['url'] ?? null);
        $this->assertSame('https://server8.mp3quran.net/afs/114.mp3', AdhkarLibrary::audio('evening', '114.mp3')['url'] ?? null);
        // Elsewhere hisnmuslim.com's own numbering applies.
        $this->assertSame('https://www.hisnmuslim.com/audio/ar/112.mp3', AdhkarLibrary::audio('sleep', '112.mp3')['url'] ?? null);
        $this->assertNull(AdhkarLibrary::audio('sleep', '../112.mp3'));
        $this->assertNull(AdhkarLibrary::audio('sleep', 'https://evil.test/1.mp3'));
    }

    public function test_the_adhkar_data_is_the_unchanged_mac_app_copy(): void
    {
        $this->assertSame(
            '71e4c4c27d981f8bcf7ca0d6c6c65ca1544d51db62c947ab39a575731a501aed',
            hash_file('sha256', AdhkarLibrary::dataPath()),
        );
    }

    public function test_category_names_are_translated_in_every_language(): void
    {
        foreach (['en', 'fr', 'ar'] as $locale) {
            $strings = json_decode((string) file_get_contents(lang_path("$locale/adhkar.json")), true);
            foreach (AdhkarLibrary::CATEGORIES as $category) {
                $this->assertNotEmpty($strings["cat_$category"] ?? null, "$locale: cat_$category");
            }
        }
    }

    public function test_every_content_string_exists_in_every_language(): void
    {
        foreach (['adhkar', 'quran'] as $group) {
            $english = array_keys(json_decode((string) file_get_contents(lang_path("en/$group.json")), true));
            foreach (['fr', 'ar'] as $locale) {
                $other = array_keys(json_decode((string) file_get_contents(lang_path("$locale/$group.json")), true));
                $this->assertEqualsCanonicalizing($english, $other, "$locale/$group.json");
            }
        }
    }
}
