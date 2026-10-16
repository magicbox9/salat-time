<?php

namespace Tests\Feature\Prayers;

use App\Models\PrayerLog;
use App\Services\Hasanat\HasanatCalculator;
use Carbon\CarbonImmutable;
use Tests\TestCase;

/** Each rule of config/hasanat.php, one at a time. No database. */
class HasanatCalculatorTest extends TestCase
{
    private function calc(): HasanatCalculator
    {
        return new HasanatCalculator(config('hasanat'));
    }

    public function test_base_points_follow_the_status_order(): void
    {
        $points = fn (string $status) => $this->calc()->breakdown('dhuhr', $status)['total'];

        $this->assertSame(10, $points('on_time'));
        $this->assertSame(6, $points('late'));
        $this->assertSame(4, $points('qada'));
        $this->assertSame(0, $points('missed'));
        $this->assertTrue($points('on_time') > $points('late') && $points('late') > $points('qada') && $points('qada') > 0);
    }

    public function test_praying_at_the_mosque_adds_a_bonus(): void
    {
        $parts = $this->calc()->breakdown('asr', 'on_time', 'mosque');

        $this->assertSame(5, $parts['mosque']);
        $this->assertSame(15, $parts['total']);
        $this->assertSame(0, $this->calc()->breakdown('asr', 'on_time', 'work')['mosque']);
    }

    public function test_congregation_counts_a_little_more_for_fajr_and_isha(): void
    {
        $this->assertSame(5, $this->calc()->breakdown('dhuhr', 'on_time', 'home', true)['congregation']);
        $this->assertSame(7, $this->calc()->breakdown('fajr', 'on_time', 'home', true)['congregation']);
        $this->assertSame(7, $this->calc()->breakdown('isha', 'on_time', 'home', true)['congregation']);
        $this->assertSame(0, $this->calc()->breakdown('isha', 'on_time', 'home', false)['congregation']);
        // Fajr at the mosque in congregation, on time: 10 + 5 + 7.
        $this->assertSame(22, $this->calc()->breakdown('fajr', 'on_time', 'mosque', true)['total']);
    }

    public function test_a_missed_prayer_earns_nothing_whatever_else_was_recorded(): void
    {
        $parts = $this->calc()->breakdown('fajr', 'missed', 'mosque', true, ['rakaat' => 2, 'stillness' => 1], 7);

        $this->assertSame(0, $parts['total']);
        $this->assertSame(0, $parts['mosque'] + $parts['congregation'] + $parts['streak'] + $parts['khushu'] + $parts['rakaat']);
    }

    public function test_the_streak_bonus_grows_per_day_and_is_capped(): void
    {
        $streak = fn (int $days, string $status = 'on_time') => $this->calc()->breakdown('maghrib', $status, streakDays: $days)['streak'];

        $this->assertSame(0, $streak(0));
        $this->assertSame(1, $streak(1));
        $this->assertSame(3, $streak(3));
        $this->assertSame(7, $streak(7));
        $this->assertSame(7, $streak(40));          // capped at max_days
        $this->assertSame(3, $streak(3, 'qada'));   // made-up prayers keep the streak
    }

    public function test_khushu_bonus_scales_with_stillness_above_the_threshold(): void
    {
        $khushu = fn (?float $stillness) => $this->calc()->breakdown('isha', 'on_time', metrics: ['stillness' => $stillness])['khushu'];

        $this->assertSame(5, $khushu(1.0));
        $this->assertSame(3, $khushu(0.6));
        $this->assertSame(0, $khushu(0.2));
        $this->assertSame(0, $khushu(0.0));
        $this->assertSame(0, $khushu(null));
    }

    public function test_complete_rakaat_must_reach_the_fard_count(): void
    {
        $rakaat = fn (string $prayer, int $count) => $this->calc()->breakdown($prayer, 'on_time', metrics: ['rakaat' => $count])['rakaat'];

        $this->assertSame(3, $rakaat('dhuhr', 4));
        $this->assertSame(0, $rakaat('dhuhr', 3));
        $this->assertSame(3, $rakaat('fajr', 2));
        $this->assertSame(3, $rakaat('maghrib', 3));
        $this->assertSame(0, $rakaat('isha', 2));
    }

    public function test_friday_dhuhr_at_the_mosque_in_congregation_is_jumua_with_two_rakaat(): void
    {
        $calc = $this->calc();

        $this->assertSame(2, $calc->fardRakaat('dhuhr', 'mosque', true, true));
        $this->assertSame(4, $calc->fardRakaat('dhuhr', 'home', false, true));
        $this->assertSame(3, $calc->breakdown('dhuhr', 'on_time', 'mosque', true, ['rakaat' => 2], isFriday: true)['rakaat']);
        $this->assertSame(0, $calc->breakdown('dhuhr', 'on_time', 'home', false, ['rakaat' => 2], isFriday: true)['rakaat']);
    }

    public function test_metrics_apply_only_when_present(): void
    {
        $without = $this->calc()->breakdown('asr', 'on_time');
        $with = $this->calc()->breakdown('asr', 'on_time', metrics: ['rakaat' => 4, 'stillness' => 1.0]);

        $this->assertSame(0, $without['khushu'] + $without['rakaat']);
        $this->assertSame(10 + 5 + 3, $with['total']);
    }

    public function test_a_stored_log_is_scored_with_its_date(): void
    {
        // 2 January 2026 is a Friday.
        $log = new PrayerLog([
            'prayer_date' => CarbonImmutable::parse('2026-01-02'),
            'prayer' => 'dhuhr',
            'status' => 'on_time',
            'place' => 'mosque',
            'in_congregation' => true,
            'metrics' => ['rakaat' => 2, 'stillness' => 1],
        ]);

        // 10 base + 5 mosque + 5 congregation + 5 khushu + 3 rakaat + 2 streak days.
        $this->assertSame(30, $this->calc()->forLog($log, 2));
    }

    public function test_numbers_come_from_the_config(): void
    {
        $calc = new HasanatCalculator([
            'base' => ['on_time' => 1, 'late' => 1, 'qada' => 1, 'missed' => 0],
            'place' => ['mosque' => 100],
            'congregation' => ['default' => 0],
            'streak' => ['statuses' => ['on_time'], 'per_day' => 2, 'max_days' => 2],
            'metrics' => ['khushu' => ['threshold' => 0, 'max' => 0], 'complete_rakaat' => 0],
            'fard_rakaat' => [],
        ]);

        $this->assertSame(101, $calc->breakdown('fajr', 'on_time', 'mosque')['total']);
        $this->assertSame(1 + 4, $calc->breakdown('fajr', 'on_time', streakDays: 5)['total']);
        $this->assertSame(1, $calc->breakdown('fajr', 'late', streakDays: 5)['total']);
    }
}
