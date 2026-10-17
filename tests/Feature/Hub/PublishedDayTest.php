<?php

namespace Tests\Feature\Hub;

use App\Http\Controllers\Hub\Support\PublishedDay;
use PHPUnit\Framework\TestCase;

/** A published day made safe for the hub's clocks: same values, clock format, nothing guessed. */
class PublishedDayTest extends TestCase
{
    /** @return array<string, mixed> */
    private function day(array $times, array $iqama = [], ?string $jumua = null): array
    {
        return [
            'date' => '2026-10-16',
            'times' => array_combine(['fajr', 'shuruq', 'dhuhr', 'asr', 'maghrib', 'isha'], $times),
            'iqama' => $iqama + ['fajr' => null, 'dhuhr' => null, 'asr' => null, 'maghrib' => null, 'isha' => null],
            'jumua' => $jumua,
        ];
    }

    public function test_clock_times_are_normalised(): void
    {
        $clean = PublishedDay::clean($this->day(['5:07', '07h30', ' 13:00 ', '16:00:00', '18H30', '20:00'], ['fajr' => '5:20', 'isha' => '25:10'], '13h30'));

        $this->assertSame(['fajr' => '05:07', 'shuruq' => '07:30', 'dhuhr' => '13:00', 'asr' => '16:00', 'maghrib' => '18:30', 'isha' => '20:00'], $clean['times']);
        $this->assertSame('05:20', $clean['iqama']['fajr']);
        $this->assertNull($clean['iqama']['isha']);
        $this->assertSame('13:30', $clean['jumua']);
        $this->assertSame('2026-10-16', $clean['date']);
    }

    public function test_a_day_with_a_missing_or_unreadable_time_is_not_shown(): void
    {
        $this->assertNull(PublishedDay::clean(null));
        $this->assertNull(PublishedDay::clean($this->day(['06:00', '07:30', '13:00', '16:00', '19:00', ''])));
        $this->assertNull(PublishedDay::clean($this->day(['06:00', 'ERROR', '13:00', '16:00', '19:00', '20:30'])));
        $this->assertNull(PublishedDay::clean($this->day(['06:00', '07:30', '24:10', '16:00', '19:00', '20:30'])));
    }

    public function test_a_mosques_own_jumua_wording_is_kept(): void
    {
        $times = ['06:00', '07:30', '13:00', '16:00', '19:00', '20:30'];

        $this->assertSame('13h30 et 14h30', PublishedDay::clean($this->day($times, [], ' 13h30 et 14h30 '))['jumua']);
        $this->assertNull(PublishedDay::clean($this->day($times, [], ''))['jumua']);
    }
}
