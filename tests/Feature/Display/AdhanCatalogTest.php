<?php

namespace Tests\Feature\Display;

use App\Models\MosqueDisplaySetting;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\Client\Request;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Process;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Sleep;
use Tests\TestCase;

class AdhanCatalogTest extends TestCase
{
    use DisplayFixtures, RefreshDatabase;

    private const MP3 = "ID3\x04\x00\x00\x00\x00\x00\x00";

    protected function setUp(): void
    {
        parent::setUp();
        Storage::fake('public');
        Http::preventStrayRequests();
        Sleep::fake();
    }

    private function mp3(int $bytes = 30000): string
    {
        return self::MP3.str_repeat("\x00", $bytes);
    }

    public function test_the_catalog_is_empty_until_recordings_are_fetched(): void
    {
        $this->getJson('/adhan/catalog.json')->assertOk()->assertExactJson(['adhans' => []]);
    }

    public function test_it_lists_the_recordings_present_on_the_server(): void
    {
        Storage::disk('public')->put('adhan/adhan_madinah.mp3', $this->mp3());
        Storage::disk('public')->put('adhan/adhan_makkah_mulla.mp3', $this->mp3());
        Storage::disk('public')->put('adhan/adhan_aqsa.mp3', 'tiny');              // a failed download
        Storage::disk('public')->put('adhan/adhan_local_recording.mp3', $this->mp3());
        Storage::disk('public')->put('adhan/notes.txt', $this->mp3());

        $adhans = $this->getJson('/adhan/catalog.json')->assertOk()->json('adhans');

        $this->assertSame(['makkah_mulla', 'madinah', 'file:adhan_local_recording'], array_column($adhans, 'id'));
        $this->assertSame('Makkah — Sheikh Ali Ibn Ahmed Mala', $adhans[0]['name']);
        $this->assertStringEndsWith('/storage/adhan/adhan_makkah_mulla.mp3', $adhans[0]['url']);
    }

    public function test_every_listed_recording_can_be_chosen_in_the_settings(): void
    {
        $longest = str_repeat('a', 59);
        Storage::disk('public')->put("adhan/$longest.mp3", $this->mp3());
        Storage::disk('public')->put('adhan/'.str_repeat('b', 60).'.mp3', $this->mp3());   // its id would be too long

        $ids = array_column($this->getJson('/adhan/catalog.json')->json('adhans'), 'id');
        $this->assertSame(["file:$longest"], $ids);

        $mosque = $this->mosque();
        $this->actingAs($this->managerOf($mosque))
            ->put("/manage/{$mosque->slug}/display", ['adhan_id' => $ids[0], 'fajr_adhan_id' => $ids[0]])
            ->assertSessionHasNoErrors();
        $this->assertSame("file:$longest", $mosque->displaySetting()->first()->settings['adhan_id']);
    }

    public function test_a_mosque_adds_its_own_adhan(): void
    {
        $mosque = $this->mosque();
        Storage::disk('public')->put("adhan/mosques/{$mosque->id}/own.mp3", $this->mp3());
        MosqueDisplaySetting::query()->create(['mosque_id' => $mosque->id, 'settings' => [], 'adhan_audio_path' => "adhan/mosques/{$mosque->id}/own.mp3"]);

        $this->getJson("/adhan/catalog.json?mosque={$mosque->slug}")
            ->assertOk()
            ->assertJsonPath('adhans.0.id', "mosque:{$mosque->id}")
            ->assertJsonPath('adhans.0.name', $mosque->name);

        $this->getJson('/adhan/catalog.json')->assertJsonCount(0, 'adhans');
        $this->getJson('/adhan/catalog.json?mosque=../../etc')->assertUnprocessable();
        $this->getJson("/mosques/{$mosque->slug}/display.json")->assertJsonPath('catalog.0.id', "mosque:{$mosque->id}");
    }

    public function test_the_fetch_command_downloads_with_the_referer_and_checks_each_file(): void
    {
        Storage::disk('public')->put('adhan/adhan_makkah_mulla.mp3', $this->mp3());   // already there
        Http::fake([
            'media.assabile.com/assabile/adhan_3435370/b30ca9a3e115.mp3' => Http::response($this->mp3(40000)),
            'media.assabile.com/assabile/adhan_3435370/768559b47c2e.mp3' => Http::response('<html>Forbidden</html>'.str_repeat(' ', 30000)),
            'media.assabile.com/assabile/adhan_3435370/f5370aa1a7e2.mp3' => Http::response($this->mp3(100)),
            'media.assabile.com/*' => Http::response('', 404),
        ]);

        $this->artisan('adhan:fetch')->assertFailed();

        $disk = Storage::disk('public');
        $this->assertTrue($disk->exists('adhan/adhan_madinah.mp3'));
        $this->assertFalse($disk->exists('adhan/adhan_aqsa.mp3'), 'an HTML page is not an MP3');
        $this->assertFalse($disk->exists('adhan/adhan_dossari.mp3'), 'too small to be a recording');
        Http::assertNotSent(fn (Request $request) => str_contains($request->url(), '166d1f7c435a'));
        Http::assertSent(fn (Request $request) => str_contains($request->url(), 'b30ca9a3e115')
            && $request->hasHeader('Referer', 'https://www.assabile.com/')
            && str_contains($request->header('User-Agent')[0] ?? '', 'Safari'));
        Http::assertNotSent(fn (Request $request) => str_contains($request->url(), 'mawaqit'));
    }

    public function test_the_fetch_command_succeeds_when_every_file_is_present(): void
    {
        foreach (config('display.adhan.recordings') as $recording) {
            Storage::disk('public')->put("adhan/{$recording['file']}", $this->mp3());
        }
        // The official adhan's two versions, already rendered.
        foreach (['regular', 'fajr'] as $version) {
            Storage::disk('public')->put('adhan/'.config("display.adhan.official.$version.file"), $this->mp3());
        }

        $this->artisan('adhan:fetch')->assertSuccessful();
        Http::assertNothingSent();
    }

    public function test_the_fetch_command_renders_the_official_versions_with_ffmpeg(): void
    {
        Process::fake(function ($process) {
            // ffmpeg's last argument is the output file: write a playable stand-in.
            file_put_contents(end($process->command), $this->mp3());

            return Process::result();
        });
        foreach (config('display.adhan.recordings') as $recording) {
            Storage::disk('public')->put("adhan/{$recording['file']}", $this->mp3());
        }

        $this->artisan('adhan:fetch')->assertSuccessful();

        Process::assertRanTimes(fn ($process) => $process->command[0] === 'ffmpeg', 2);
        Storage::disk('public')->assertExists(['adhan/adhan_official.mp3', 'adhan/adhan_official_fajr.mp3']);
    }
}
