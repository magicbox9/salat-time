<?php

namespace Tests\Feature\Mosques;

use App\Models\Mosque;
use App\Services\PrayerTimes\MosqueTimetable;
use Carbon\CarbonImmutable;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class MosqueTimetableTest extends TestCase
{
    use RefreshDatabase;

    public function test_it_reads_the_published_row_and_resolves_iqama(): void
    {
        $mosque = Mosque::factory()->withCalendar()->create(['jumua' => '13:30']);
        $day = app(MosqueTimetable::class)->day($mosque, CarbonImmutable::parse('2026-01-02', 'Europe/Paris'));

        $this->assertSame('06:00', $day['times']['fajr']);
        $this->assertSame('20:30', $day['times']['isha']);
        $this->assertSame('06:10', $day['iqama']['fajr']);
        $this->assertSame('19:05', $day['iqama']['maghrib']);
        $this->assertSame('13:30', $day['jumua']);   // 2 January 2026 is a Friday
    }

    public function test_published_times_are_marked_as_the_mosques_own(): void
    {
        $mosque = Mosque::factory()->withCalendar()->create();
        $timetable = app(MosqueTimetable::class);
        $day = $timetable->day($mosque, CarbonImmutable::now('Europe/Paris'));

        $this->assertSame('published', $day['source']);
        $this->assertArrayNotHasKey('method', $day);
        $this->assertTrue($timetable->publishesTimes($mosque));
    }

    public function test_a_gap_in_a_published_calendar_is_never_filled_with_a_calculation(): void
    {
        $mosque = Mosque::factory()->withCalendar()->create();
        $calendar = $mosque->calendars()->first();
        $days = $calendar->days;
        $days[0][4] = [];   // 5 January: nothing published
        $calendar->update(['days' => $days]);

        $this->assertNull(app(MosqueTimetable::class)->day($mosque, CarbonImmutable::parse(now()->year.'-01-05', 'Europe/Paris')));
    }

    public function test_iqama_values_are_resolved_like_the_mac_app(): void
    {
        $this->assertSame('13:10', MosqueTimetable::resolveIqama('+10', '13:00'));
        $this->assertSame('00:05', MosqueTimetable::resolveIqama('+10', '23:55'));
        $this->assertSame('13:30', MosqueTimetable::resolveIqama('13:30', '13:00'));
        $this->assertNull(MosqueTimetable::resolveIqama('', '13:00'));
        $this->assertNull(MosqueTimetable::resolveIqama('soon', '13:00'));
    }

    public function test_nearby_search_orders_by_distance(): void
    {
        $far = Mosque::factory()->at(48.90, 2.40)->create();
        $near = Mosque::factory()->at(48.8571, 2.3510)->create();
        Mosque::factory()->at(45.75, 4.85)->create();   // Lyon: outside the radius

        $ids = Mosque::near(48.8566, 2.3522, 20)->pluck('id')->all();

        $this->assertSame([$near->id, $far->id], $ids);
    }
}
