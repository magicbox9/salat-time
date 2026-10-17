<?php

namespace Tests\Feature\Display;

use App\Models\Mosque;
use App\Models\MosqueDisplaySetting;
use App\Models\User;
use App\Services\Display\DisplaySettings;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class DisplaySettingsValidationTest extends TestCase
{
    use DisplayFixtures, RefreshDatabase;

    private Mosque $mosque;

    private User $manager;

    protected function setUp(): void
    {
        parent::setUp();
        $this->mosque = $this->mosque();
        $this->manager = $this->managerOf($this->mosque);
    }

    private function save(array $values)
    {
        return $this->actingAs($this->manager)->put("/manage/{$this->mosque->slug}/display", $values);
    }

    /** @return array<string, mixed> */
    private function stored(): array
    {
        return $this->mosque->displaySetting()->first()?->settings ?? [];
    }

    public function test_unknown_keys_are_dropped(): void
    {
        $this->save([
            'theme' => 'minimal',
            'is_admin' => true,
            'background_path' => '../../.env',
            'mosque_id' => 999,
            'muted' => true,                       // personal screens only
            'blackout_minutes' => ['fajr' => 5, 'sunset' => 30],
        ])->assertSessionHasNoErrors();

        $stored = $this->stored();
        $this->assertSame('minimal', $stored['theme']);
        $this->assertArrayNotHasKey('is_admin', $stored);
        $this->assertArrayNotHasKey('background_path', $stored);
        $this->assertArrayNotHasKey('mosque_id', $stored);
        $this->assertArrayNotHasKey('muted', $stored);
        $this->assertSame(5, $stored['blackout_minutes']['fajr']);
        $this->assertArrayNotHasKey('sunset', $stored['blackout_minutes']);
        $this->assertEqualsCanonicalizing(DisplaySettings::keys(DisplaySettings::MOSQUE), array_keys($stored));
        $this->assertNull($this->mosque->displaySetting()->first()->background_path);
    }

    public function test_values_out_of_range_or_unknown_are_refused(): void
    {
        $this->save([
            'theme' => 'neon',
            'orientation' => 'diagonal',
            'hijri_adjust' => 3,
            'approaching_minutes' => -1,
            'adhan_minutes' => 0,
            'iqama_seconds' => 500,
            'rotation_seconds' => 2,
            'volume' => 101,
            'blackout_minutes' => ['isha' => 120],
            'accent_color' => 'red',
            'languages' => ['ar', 'fr', 'en'],
            'rotation' => ['quran', 'weather'],
            'adhan_id' => '../../etc/passwd',
            'night_from' => '25:00',
            'show_seconds' => 'yes',
        ])->assertSessionHasErrors([
            'theme', 'orientation', 'hijri_adjust', 'approaching_minutes', 'adhan_minutes', 'iqama_seconds',
            'rotation_seconds', 'volume', 'blackout_minutes.isha', 'accent_color', 'languages', 'rotation.1',
            'adhan_id', 'night_from', 'show_seconds',
        ]);

        $this->assertDatabaseCount('mosque_display_settings', 0);
    }

    public function test_a_partial_update_keeps_the_other_choices(): void
    {
        $this->save(['theme' => 'arabesque', 'blackout_minutes' => ['fajr' => 20, 'jumua' => 60]]);
        $this->save(['blackout_minutes' => ['isha' => 15], 'languages' => ['fr', 'ar'], 'accent_color' => '#AABBCC']);

        $stored = $this->stored();
        $this->assertSame('arabesque', $stored['theme']);
        $this->assertEquals(['fajr' => 20, 'dhuhr' => 12, 'asr' => 10, 'maghrib' => 8, 'isha' => 15, 'jumua' => 60], $stored['blackout_minutes']);
        $this->assertSame(['fr', 'ar'], $stored['languages']);
        $this->assertSame('#aabbcc', $stored['accent_color']);
    }

    public function test_limits_are_accepted(): void
    {
        $this->save([
            'hijri_adjust' => -2,
            'approaching_minutes' => 0,
            'volume' => 100,
            'rotation' => [],
            'adhan_mode' => 'off',
            'adhan_id' => 'mosque:12',
            'accent_color' => null,
            'night_dim' => true,
            'night_from' => '22:30',
            'night_to' => '05:15',
        ])->assertSessionHasNoErrors();

        $stored = $this->stored();
        $this->assertSame(-2, $stored['hijri_adjust']);
        $this->assertSame([], $stored['rotation']);
        $this->assertSame('mosque:12', $stored['adhan_id']);
        $this->assertNull($stored['accent_color']);
        $this->assertSame('22:30', $stored['night_from']);
    }

    public function test_corrupt_stored_settings_fall_back_to_the_defaults(): void
    {
        MosqueDisplaySetting::query()->create([
            'mosque_id' => $this->mosque->id,
            'settings' => ['theme' => 'hacker', 'volume' => 900, 'languages' => 'ar', 'show_iqama' => false, 'evil' => '<script>'],
        ]);

        $settings = DisplaySettings::forMosque($this->mosque->fresh());

        $this->assertSame('classic', $settings['theme']);
        $this->assertSame(80, $settings['volume']);
        $this->assertSame(['ar', 'fr'], $settings['languages']);
        $this->assertFalse($settings['show_iqama']);
        $this->assertArrayNotHasKey('evil', $settings);
    }
}
