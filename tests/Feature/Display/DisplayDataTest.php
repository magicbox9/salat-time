<?php

namespace Tests\Feature\Display;

use App\Models\Mosque;
use App\Models\MosqueDisplayMessage;
use App\Models\MosquePost;
use App\Services\Content\AdhkarLibrary;
use App\Services\Content\QuranCorpus;
use App\Services\Content\QuranTranslations;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class DisplayDataTest extends TestCase
{
    use DisplayFixtures, RefreshDatabase;

    private function message(Mosque $mosque, string $body, array $attributes = []): MosqueDisplayMessage
    {
        $message = new MosqueDisplayMessage;
        $message->forceFill(['mosque_id' => $mosque->id, 'body' => $body, ...$attributes])->save();

        return $message;
    }

    public function test_it_holds_a_week_of_published_times_and_the_jumua(): void
    {
        $mosque = $this->mosque();
        $mosque->forceFill(['jumua' => '13:30', 'jumua2' => '14:30', 'jumua3' => 'soon'])->save();

        $response = $this->getJson("/mosques/{$mosque->slug}/display.json")->assertOk();

        $today = now('Europe/Paris')->toDateString();
        $response
            ->assertJsonPath('timezone', 'Europe/Paris')
            ->assertJsonPath('today', $today)
            ->assertJsonCount(7, 'days')
            ->assertJsonPath('days.0.date', $today)
            ->assertJsonPath('days.0.times.fajr', '06:00')
            ->assertJsonPath('days.0.times.isha', '20:30')
            ->assertJsonPath('days.0.iqama.fajr', '06:10')
            ->assertJsonPath('days.6.date', now('Europe/Paris')->addDays(6)->toDateString())
            ->assertJsonPath('jumua.times', ['13:30', '14:30'])
            ->assertJsonPath('jumua.as_dhuhr', false)
            ->assertJsonPath('settings.theme', 'classic')
            ->assertJsonPath('mosque.slug', $mosque->slug)
            ->assertJsonStructure(['labels' => ['ar' => ['prayer_fajr', 'iqama', 'next_prayer'], 'fr', 'en'], 'catalog', 'rotation' => ['verses', 'adhkar', 'after_prayer', 'posts']]);
        $this->assertStringContainsString('max-age=60', (string) $response->headers->get('Cache-Control'));
        $this->assertSame('العشاء', $response->json('labels.ar.prayer_isha'));
    }

    public function test_a_mosque_without_a_calendar_shows_calculated_times_marked_as_such(): void
    {
        $mosque = Mosque::factory()->create();

        $days = $this->getJson("/mosques/{$mosque->slug}/display.json")
            ->assertOk()
            ->assertJsonPath('yesterday.source', 'calculated')
            ->json('days');

        $this->assertCount(7, $days);
        $this->assertSame(['calculated'], array_values(array_unique(array_column($days, 'source'))));
        $this->assertSame([null, null, null, null, null], array_values($days[0]['iqama']));
    }

    public function test_only_messages_inside_their_window_are_shown(): void
    {
        $mosque = $this->mosque();
        $this->message($mosque, 'Always');
        $this->message($mosque, 'Running', ['starts_at' => now()->subDay(), 'ends_at' => now()->addDay(), 'sort' => 2]);
        $this->message($mosque, 'Later', ['starts_at' => now()->addHour()]);
        $this->message($mosque, 'Over', ['ends_at' => now()->subMinute()]);
        $this->message($mosque, 'Paused', ['active' => false]);
        $this->message(Mosque::factory()->create(), 'Another mosque');

        $bodies = collect($this->getJson("/mosques/{$mosque->slug}/display.json")->json('messages'))->pluck('body')->all();

        $this->assertSame(['Always', 'Running'], $bodies);
    }

    public function test_verses_come_unchanged_from_the_verified_corpus_and_translations(): void
    {
        $mosque = $this->mosque();
        $verses = $this->getJson("/mosques/{$mosque->slug}/display.json")->json('rotation.verses');
        $corpus = app(QuranCorpus::class);
        $translations = app(QuranTranslations::class);

        $this->assertCount(count(config('display.verses')), $verses);
        foreach ($verses as $verse) {
            $ayat = collect($corpus->ayat($verse['surah']))->keyBy('ayah');
            $numbers = [];
            foreach ($verse['ayat'] as $ayah) {
                $this->assertSame($ayat[$ayah['ayah']]['text'], $ayah['text'], "{$verse['key']} must be the corpus text");
                $numbers[] = $ayah['ayah'];
            }
            $this->assertSame($corpus->surah($verse['surah'])['name_ar'], $verse['surah_name_ar']);
            foreach (['en', 'fr'] as $code) {
                $rows = $translations->forSurah($code, $verse['surah'])['ayat'];
                $expected = implode(' ', array_map(fn (int $n) => $rows[$n]['text'], $numbers));
                $this->assertSame($expected, $verse['translations'][$code]['text']);
                $this->assertSame(QuranTranslations::AVAILABLE[$code]['version'], $verse['translations'][$code]['version']);
            }
        }
    }

    public function test_adhkar_come_unchanged_from_hisn_al_muslim(): void
    {
        $mosque = $this->mosque();
        $rotation = $this->getJson("/mosques/{$mosque->slug}/display.json")->json('rotation');
        $library = app(AdhkarLibrary::class);
        $known = collect([...$library->items('morning'), ...$library->items('evening')])->keyBy('id');

        $this->assertNotEmpty($rotation['adhkar']);
        foreach ($rotation['adhkar'] as $dhikr) {
            $source = $known[$dhikr['id']];
            $this->assertSame($source['arabic'], $dhikr['arabic']);
            $this->assertSame($source['virtue'], $dhikr['virtue']);
            $this->assertSame($source['source'], $dhikr['source']);
            $this->assertLessThanOrEqual(config('display.adhkar_max_length'), mb_strlen($dhikr['arabic']));
        }

        $after = collect($library->items('post_prayer'))->keyBy('id');
        $this->assertCount($after->count(), $rotation['after_prayer']);
        foreach ($rotation['after_prayer'] as $dhikr) {
            $this->assertSame($after[$dhikr['id']]['arabic'], $dhikr['arabic']);
        }
    }

    public function test_only_published_posts_are_listed(): void
    {
        $mosque = $this->mosque();
        MosquePost::factory()->for($mosque)->create(['title' => 'Published', 'published_at' => now()->subHour()]);
        MosquePost::factory()->for($mosque)->create(['title' => 'Draft', 'published_at' => null]);
        MosquePost::factory()->for($mosque)->create(['title' => 'Future', 'published_at' => now()->addDay()]);
        MosquePost::factory()->for($mosque)->create(['title' => 'Deleted', 'published_at' => now()->subHour()])->delete();

        $titles = collect($this->getJson("/mosques/{$mosque->slug}/display.json")->json('rotation.posts'))->pluck('title')->all();

        $this->assertSame(['Published'], $titles);
    }

    public function test_a_change_by_a_manager_is_served_at_once(): void
    {
        $mosque = $this->mosque();
        $this->getJson("/mosques/{$mosque->slug}/display.json")->assertJsonPath('settings.theme', 'classic');

        $this->actingAs($this->managerOf($mosque))->put("/manage/{$mosque->slug}/display", ['theme' => 'minimal']);
        $this->actingAs($this->managerOf($mosque))->post("/manage/{$mosque->slug}/display/messages", ['body' => 'Fresh']);

        $this->getJson("/mosques/{$mosque->slug}/display.json")
            ->assertJsonPath('settings.theme', 'minimal')
            ->assertJsonPath('messages.0.body', 'Fresh');
    }

    public function test_the_stamp_tells_screens_when_to_fetch_again(): void
    {
        $mosque = $this->mosque();
        $stampUrl = "/mosques/{$mosque->slug}/display/stamp.json";
        $first = $this->getJson($stampUrl)->assertOk()->assertHeader('Cache-Control', 'no-store, private')->json('stamp');

        $this->assertMatchesRegularExpression('/^[0-9a-f]{16}$/', $first);
        $this->getJson("/mosques/{$mosque->slug}/display.json")->assertJsonPath('stamp', $first);
        $this->assertSame($first, $this->getJson($stampUrl)->json('stamp'));

        // A manager's change: a new stamp at once.
        $this->actingAs($this->managerOf($mosque))->put("/manage/{$mosque->slug}/display", ['theme' => 'minimal']);
        $second = $this->getJson($stampUrl)->json('stamp');
        $this->assertNotSame($first, $second);

        // A message scheduled for later: the stamp changes when it starts, and
        // the screen then gets it (not a minute-old copy without it).
        $this->message($mosque, 'Janaza after Dhuhr', ['starts_at' => now()->addMinutes(10)]);
        $this->getJson("/mosques/{$mosque->slug}/display.json")->assertJsonPath('messages', []);
        $this->assertSame($second, $this->getJson($stampUrl)->json('stamp'));

        $this->travel(11)->minutes();
        $third = $this->getJson($stampUrl)->json('stamp');
        $this->assertNotSame($second, $third);
        $this->getJson("/mosques/{$mosque->slug}/display.json")
            ->assertJsonPath('stamp', $third)
            ->assertJsonPath('messages.0.body', 'Janaza after Dhuhr');

        $this->getJson('/mosques/no-such-mosque/display/stamp.json')->assertNotFound();
    }

    public function test_the_display_routes_never_capture_other_json_paths(): void
    {
        $mosque = $this->mosque();

        $this->getJson("/mosques/{$mosque->slug}/times.json")->assertOk()->assertJsonMissingPath('rotation');
        $this->getJson('/mosques/search.json?q=x')->assertJsonMissingPath('rotation');
    }
}
