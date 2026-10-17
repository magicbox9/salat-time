<?php

namespace Tests\Feature\Discover;

use App\Http\Controllers\Discover\Support\PublishedToday;
use App\Models\Mosque;
use App\Models\MosquePrayerCalendar;
use App\Services\PrayerTimes\MosqueTimetable;
use Carbon\CarbonImmutable;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

/** The batch reader must read exactly what MosqueTimetable::day() reads. */
class PublishedTodayTest extends TestCase
{
    use RefreshDatabase;

    public function test_29_february_falls_back_to_the_28th_like_the_timetable(): void
    {
        $mosque = $this->mosqueWithCalendar(2027);   // February has 28 rows
        $this->travelTo(CarbonImmutable::parse('2028-02-29 10:00', 'Europe/Paris'));

        $this->assertSameAsTimetable($mosque);
        $this->assertSame('05:28', PublishedToday::for([$mosque])[$mosque->id]['today']['times']['fajr']);
    }

    public function test_new_years_eve_reads_tomorrow_like_the_timetable(): void
    {
        $mosque = $this->mosqueWithCalendar(2028);
        MosquePrayerCalendar::query()->create([
            'mosque_id' => $mosque->id,
            'year' => 2029,
            'timezone' => 'Europe/Paris',
            'days' => $this->days('07'),
        ]);
        $this->travelTo(CarbonImmutable::parse('2028-12-31 22:00', 'Europe/Paris'));

        $this->assertSameAsTimetable($mosque);
        $batch = PublishedToday::for([$mosque])[$mosque->id];
        $this->assertSame('2028-12-31', $batch['today']['date']);
        $this->assertSame('05:31', $batch['today']['times']['fajr']);   // 2028 calendar
        $this->assertSame('07:01', $batch['tomorrow']['times']['fajr']); // 2029 calendar
    }

    public function test_a_mosque_in_another_time_zone_uses_its_own_date(): void
    {
        $paris = $this->mosqueWithCalendar(2028);
        $reunion = $this->mosqueWithCalendar(2028, 'Indian/Reunion');
        // 22:30 in Paris is already 00:30 the next day in Réunion.
        $this->travelTo(CarbonImmutable::parse('2028-03-10 22:30', 'Europe/Paris'));

        $batch = PublishedToday::for([$paris, $reunion]);

        $this->assertSame('2028-03-10', $batch[$paris->id]['today']['date']);
        $this->assertSame('2028-03-11', $batch[$reunion->id]['today']['date']);
        $this->assertSameAsTimetable($paris);
        $this->assertSameAsTimetable($reunion);
    }

    public function test_mosques_without_a_calendar_have_no_times(): void
    {
        $mosque = Mosque::factory()->create();

        $this->assertSame(['today' => null, 'tomorrow' => null], PublishedToday::for([$mosque])[$mosque->id]);
    }

    public function test_rows_that_are_not_clock_times_count_as_unpublished(): void
    {
        // Imported calendars hold empty cells and "ERROR": no countdown to them.
        $broken = Mosque::factory()->withCalendar(['06:00', '07:30', '13:00', '16:00', '19:00', ''])->create();
        $error = Mosque::factory()->withCalendar(['06:00', 'ERROR', '13:00', '16:00', '19:00', '20:30'])->create();
        $written = Mosque::factory()->withCalendar(['6:05', '07h30', '13:00', '16:00:00', '18h30', '20:00'])->create();

        $batch = PublishedToday::for([$broken, $error, $written]);

        $this->assertSame(['today' => null, 'tomorrow' => null], $batch[$broken->id]);
        $this->assertSame(['today' => null, 'tomorrow' => null], $batch[$error->id]);
        $this->assertSame(
            ['fajr' => '06:05', 'shuruq' => '07:30', 'dhuhr' => '13:00', 'asr' => '16:00', 'maghrib' => '18:30', 'isha' => '20:00'],
            $batch[$written->id]['today']['times'],
        );
    }

    private function assertSameAsTimetable(Mosque $mosque): void
    {
        $timetable = app(MosqueTimetable::class);
        $now = CarbonImmutable::now($mosque->timezone);
        $batch = PublishedToday::for([$mosque])[$mosque->id];

        foreach (['today' => $now, 'tomorrow' => $now->addDay()] as $key => $date) {
            $day = $timetable->day($mosque, $date);
            $this->assertSame(['date' => $day['date'], 'times' => $day['times']], $batch[$key], $key);
        }
    }

    private function mosqueWithCalendar(int $year, string $timezone = 'Europe/Paris'): Mosque
    {
        $mosque = Mosque::factory()->create(['timezone' => $timezone]);
        MosquePrayerCalendar::query()->create([
            'mosque_id' => $mosque->id,
            'year' => $year,
            'timezone' => $timezone,
            'days' => $this->days('05', $year),
        ]);

        return $mosque;
    }

    /**
     * Distinct times for every day: fajr = "{hour}:{day}" so each row is recognisable.
     *
     * @return list<list<list<string>>>
     */
    private function days(string $hour, int $year = 2029): array
    {
        $months = [];
        for ($m = 1; $m <= 12; $m++) {
            $count = (int) date('t', mktime(0, 0, 0, $m, 1, $year));
            $rows = [];
            for ($d = 1; $d <= $count; $d++) {
                $rows[] = [sprintf('%s:%02d', $hour, $d), '07:30', '13:00', '16:00', '19:00', '20:30'];
            }
            $months[] = $rows;
        }

        return $months;
    }
}
