<?php

namespace Tests\Feature\Mosques;

use App\Models\Mosque;
use App\Services\PrayerTimes\MosqueTimetable;
use Carbon\CarbonImmutable;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

/**
 * A mosque that publishes no calendar gets times calculated for its place,
 * always marked as calculated. The expected values are the method's own
 * smoke values (tests/Fixtures/prayer-method/smoke_values.json).
 */
class CalculatedTimesTest extends TestCase
{
    use RefreshDatabase;

    public function test_a_paris_mosque_follows_the_convention_of_its_departement(): void
    {
        $mosque = Mosque::factory()->at(48.853, 2.3499)->create(['postcode' => '75004']);

        $day = $this->day($mosque, '2026-06-21');

        $this->assertSame('calculated', $day['source']);
        $this->assertSame(['id' => 'fr-dept', 'departement' => '75', 'version' => 'fr-dept-2026.1'], $day['method']);
        $this->assertSame(
            ['fajr' => '04:00', 'shuruq' => '05:47', 'dhuhr' => '13:53', 'asr' => '18:10', 'maghrib' => '22:01', 'isha' => '23:31'],
            $day['times'],
        );
        $this->assertSame(['fajr', 'dhuhr', 'asr', 'maghrib', 'isha'], array_keys($day['iqama']));
        $this->assertSame([null, null, null, null, null], array_values($day['iqama']));
        $this->assertFalse(app(MosqueTimetable::class)->publishesTimes($mosque));
    }

    public function test_the_rhone_uses_its_own_convention(): void
    {
        $mosque = Mosque::factory()->at(45.7578, 4.832)->create(['postcode' => '69002']);

        $this->assertSame(
            ['fajr' => '06:53', 'shuruq' => '08:18', 'dhuhr' => '12:55', 'asr' => '15:04', 'maghrib' => '17:26', 'isha' => '18:42'],
            $this->day($mosque, '2026-01-15')['times'],
        );
    }

    public function test_switching_the_departement_table_off_uses_uoif_with_safety_minutes(): void
    {
        config(['prayertimes.france_table' => false]);
        $mosque = Mosque::factory()->at(48.853, 2.3499)->create(['postcode' => '75004']);

        $day = $this->day($mosque, '2026-06-21');

        $this->assertSame('uoif-safety', $day['method']['id']);
        $this->assertSame(['04:09', '05:47', '13:57', '18:10', '22:01', '23:37'], array_values($day['times']));
    }

    public function test_without_a_postcode_metropolitan_france_uses_the_national_convention(): void
    {
        $mosque = Mosque::factory()->at(46.5, 2.5)->create(['postcode' => null]);

        $this->assertSame(['id' => 'fr-national', 'departement' => null, 'version' => 'fr-dept-2026.1'], $this->day($mosque, '2026-03-10')['method']);
    }

    public function test_overseas_mosques_use_the_standard_method(): void
    {
        $mayotte = Mosque::factory()->at(-12.78, 45.23)->create([
            'postcode' => '97600', 'country_code' => 'YT', 'territory' => 'YT', 'timezone' => 'Indian/Mayotte',
        ]);
        // A record filed under FR but on Mayotte time is not metropolitan either.
        $filedUnderFrance = Mosque::factory()->at(-12.78, 45.23)->create([
            'postcode' => null, 'country_code' => 'FR', 'territory' => 'FR', 'timezone' => 'Indian/Mayotte',
        ]);

        $this->assertSame('mwl', $this->day($mayotte, '2026-03-10')['method']['id']);
        $this->assertSame('mwl', $this->day($filedUnderFrance, '2026-03-10')['method']['id']);
    }

    public function test_only_a_jumua_time_the_mosque_set_itself_is_shown(): void
    {
        $own = Mosque::factory()->create(['jumua' => '13:30']);
        $atDhuhr = Mosque::factory()->create(['jumua' => null, 'jumua_as_dhuhr' => true]);

        $this->assertSame('13:30', $this->day($own, '2026-06-19')['jumua']);       // a Friday
        $this->assertNull($this->day($own, '2026-06-20')['jumua']);
        $this->assertNull($this->day($atDhuhr, '2026-06-19')['jumua']);            // Dhuhr would be calculated
    }

    public function test_the_live_view_and_ranges_carry_the_calculated_source(): void
    {
        $mosque = Mosque::factory()->create();
        $timetable = app(MosqueTimetable::class);

        $this->assertSame('calculated', $timetable->live($mosque)['today']['source']);
        $range = $timetable->range($mosque, CarbonImmutable::now('Europe/Paris'), 31);
        $this->assertCount(31, $range);

        $this->getJson("/mosques/{$mosque->slug}/times.json?days=7")
            ->assertOk()
            ->assertJsonPath('today.source', 'calculated')
            ->assertJsonPath('days.6.source', 'calculated');
    }

    /** @return array<string, mixed> */
    private function day(Mosque $mosque, string $date): array
    {
        return app(MosqueTimetable::class)->day($mosque, CarbonImmutable::parse($date, $mosque->timezone));
    }
}
