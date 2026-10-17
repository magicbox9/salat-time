<?php

namespace Tests\Feature\Display;

use App\Console\Commands\FetchAdhanAudio;
use App\Services\Display\AdhanCatalog;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Storage;
use Tests\TestCase;

/** The official Salat Time adhan: Mansour Al-Zahrani, full at Fajr, without the Fajr passage otherwise. */
class OfficialAdhanTest extends TestCase
{
    use RefreshDatabase;

    public function test_the_official_adhan_comes_first_with_its_fajr_version(): void
    {
        Storage::fake('public');
        $mp3 = "\xFF\xFB".str_repeat('a', 30000);
        foreach (['adhan_makkah_mulla.mp3', 'adhan_zahrani.mp3', 'adhan_official.mp3', 'adhan_official_fajr.mp3'] as $file) {
            Storage::disk('public')->put("adhan/$file", $mp3);
        }

        $tracks = app(AdhanCatalog::class)->list();

        $this->assertSame(['official', 'official_fajr', 'makkah_mulla', 'zahrani'], array_column($tracks, 'id'));
        $this->assertStringEndsWith('/storage/adhan/adhan_official_fajr.mp3', $tracks[0]['fajr_url']);
        $this->assertArrayNotHasKey('fajr_url', $tracks[2]);
    }

    public function test_screens_and_the_home_default_to_the_official_adhan(): void
    {
        $this->assertSame('official', config('display.defaults.adhan_id'));
        $this->assertSame('official_fajr', config('display.defaults.fajr_adhan_id'));
        $this->assertSame('adhan_zahrani.mp3', config('display.adhan.official.source'));
    }

    public function test_the_regular_version_skips_the_fajr_only_passage(): void
    {
        $this->assertSame(
            "aselect='between(t\\,0.000\\,123.866)+gte(t\\,149.440)',asetpts=N/SR/TB",
            FetchAdhanAudio::selectFilter(config('display.adhan.official.regular.keep')),
        );
        $this->assertSame("aselect='gte(t\\,0.000)',asetpts=N/SR/TB", FetchAdhanAudio::selectFilter([[0.0, null]]));
    }
}
