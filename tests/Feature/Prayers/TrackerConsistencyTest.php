<?php

namespace Tests\Feature\Prayers;

use App\Models\PrayerLog;
use App\Models\User;
use App\Services\Hasanat\PrayerTracker;
use App\Services\Hasanat\TrackerClock;
use Carbon\CarbonImmutable;
use Illuminate\Database\Events\QueryExecuted;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Tests\TestCase;

/** Writes to one person's tracker are serialized so streak bonuses stay right. */
class TrackerConsistencyTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        $this->travelTo(CarbonImmutable::parse('2026-03-10 14:00', 'Europe/Paris'));
    }

    /** @return list<string> the SQL run by $action */
    private function queriesOf(callable $action): array
    {
        $sql = [];
        DB::listen(function (QueryExecuted $query) use (&$sql) {
            $sql[] = strtolower($query->sql);
        });
        $action();

        return $sql;
    }

    private function lockedUsers(array $sql): bool
    {
        return collect($sql)->contains(fn (string $q) => str_contains($q, 'from "users"') && str_contains($q, 'for update'));
    }

    public function test_recording_and_removing_lock_the_persons_tracker(): void
    {
        $user = User::factory()->create();
        $tracker = app(PrayerTracker::class);
        $clock = TrackerClock::for($user, 'Europe/Paris');
        $data = ['prayer_date' => '2026-03-10', 'prayer' => 'fajr', 'status' => 'on_time', 'place' => 'home'];

        $sql = $this->queriesOf(fn () => $tracker->record($user, $data, $clock));
        $this->assertTrue($this->lockedUsers($sql), 'record() must lock the user row before rescoring');

        $log = PrayerLog::query()->sole();
        $sql = $this->queriesOf(fn () => $tracker->remove($log));
        $this->assertTrue($this->lockedUsers($sql), 'remove() must lock the user row before rescoring');
        $this->assertModelMissing($log);
    }

    public function test_the_fifth_prayer_of_a_day_rescores_the_four_before_it(): void
    {
        $user = User::factory()->create();
        $tracker = app(PrayerTracker::class);
        $clock = TrackerClock::for($user, 'Europe/Paris');
        foreach (PrayerLog::PRAYERS as $prayer) {
            $tracker->record($user, ['prayer_date' => '2026-03-09', 'prayer' => $prayer, 'status' => 'on_time'], $clock);
        }

        // A complete day is a one-day streak: each of its five prayers earns +1.
        $this->assertSame([11, 11, 11, 11, 11], PrayerLog::query()->orderBy('id')->pluck('hasanat')->all());
    }
}
