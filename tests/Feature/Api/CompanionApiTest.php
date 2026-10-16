<?php

namespace Tests\Feature\Api;

use App\Models\Mosque;
use App\Models\PrayerLog;
use App\Models\User;
use Carbon\CarbonImmutable;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

/** API v1 for the iOS / Android companion apps. */
class CompanionApiTest extends TestCase
{
    use RefreshDatabase;

    private User $user;

    private string $token;

    protected function setUp(): void
    {
        parent::setUp();
        // Tuesday 10 March 2026, 14:00 in Paris.
        $this->travelTo(CarbonImmutable::parse('2026-03-10 14:00', 'Europe/Paris'));
        $this->user = User::factory()->create();
        $this->token = $this->user->createToken('iPhone', ['prayers:read', 'prayers:write'])->plainTextToken;
    }

    private function api(): static
    {
        return $this->withToken($this->token)->withHeader('X-Timezone', 'Europe/Paris');
    }

    private function ownMosque(bool $withTimes = true): Mosque
    {
        $factory = Mosque::factory();
        $mosque = ($withTimes ? $factory->withCalendar() : $factory)->create(['timezone' => 'Europe/Paris']);
        $this->user->favoriteMosques()->attach($mosque->id, ['is_primary' => true]);

        return $mosque;
    }

    /** @return array<string, mixed> */
    private function payload(array $overrides = []): array
    {
        return array_replace_recursive([
            'prayer_date' => '2026-03-10',
            'prayer' => 'dhuhr',
            'status' => 'on_time',
            'place' => 'mosque',
            'in_congregation' => true,
            'source' => 'ios',
            'metrics' => [
                'rakaat' => 4,
                'ruku' => 4,
                'sujud' => 8,
                'duration_seconds' => 420,
                'stillness' => 1,
                'started_at' => '2026-03-10T13:05:00+01:00',
                'ended_at' => '2026-03-10T13:12:00+01:00',
            ],
        ], $overrides);
    }

    public function test_a_token_is_required(): void
    {
        $this->getJson('/api/v1/me')->assertUnauthorized()->assertJsonStructure(['message']);
        $this->postJson('/api/v1/prayer-logs', $this->payload())->assertUnauthorized();
        $this->withToken('1|not-a-real-token')->getJson('/api/v1/me')->assertUnauthorized();
        $this->assertDatabaseCount('prayer_logs', 0);
    }

    public function test_a_token_without_the_abilities_is_refused(): void
    {
        $readOnly = $this->user->createToken('Watch', ['prayers:read'])->plainTextToken;

        $this->withToken($readOnly)->getJson('/api/v1/me')->assertOk();
        $this->withToken($readOnly)->postJson('/api/v1/prayer-logs', $this->payload())->assertForbidden();
        $this->assertDatabaseCount('prayer_logs', 0);
    }

    public function test_me_returns_the_profile_and_own_mosque(): void
    {
        $this->api()->getJson('/api/v1/me')
            ->assertOk()
            ->assertJsonPath('data.id', $this->user->id)
            ->assertJsonPath('data.mosque', null)
            ->assertJsonMissingPath('data.password');

        $mosque = $this->ownMosque();
        $this->api()->getJson('/api/v1/me')->assertJsonPath('data.mosque.slug', $mosque->slug);
    }

    public function test_my_mosque_times_are_the_published_ones(): void
    {
        $this->api()->getJson('/api/v1/me/mosque/times')->assertNotFound()->assertJsonPath('code', 'no_mosque');

        $this->ownMosque();
        $this->api()->getJson('/api/v1/me/mosque/times?date=2026-03-11')
            ->assertOk()
            ->assertJsonPath('data.date', '2026-03-11')
            ->assertJsonPath('data.has_times', true)
            ->assertJsonPath('data.day.times.fajr', '06:00')
            ->assertJsonPath('data.day.iqama.fajr', '06:10');

        $this->api()->getJson('/api/v1/me/mosque/times?date=11-03-2026')->assertUnprocessable()->assertJsonValidationErrors('date');
    }

    public function test_a_mosque_without_a_calendar_has_no_invented_times(): void
    {
        $this->ownMosque(withTimes: false);

        $this->api()->getJson('/api/v1/me/mosque/times')
            ->assertOk()
            ->assertJsonPath('data.has_times', false)
            ->assertJsonPath('data.day', null);
    }

    public function test_the_phone_records_a_prayer_with_sensor_metrics(): void
    {
        $mosque = $this->ownMosque();

        $this->api()->postJson('/api/v1/prayer-logs', $this->payload())
            ->assertCreated()
            ->assertJsonPath('data.source', 'ios')
            ->assertJsonPath('data.mosque_id', $mosque->id)
            ->assertJsonPath('data.metrics.sujud', 8)
            // 10 on time + 5 mosque + 5 congregation + 5 khushu + 3 rakaat.
            ->assertJsonPath('data.hasanat', 28)
            ->assertJsonPath('data.breakdown.khushu', 5)
            ->assertJsonPath('data.breakdown.rakaat', 3);

        // Sending the same prayer again updates it (200), never duplicates it.
        $this->api()->postJson('/api/v1/prayer-logs', $this->payload(['metrics' => ['stillness' => 0.2, 'rakaat' => 3]]))
            ->assertOk()
            ->assertJsonPath('data.hasanat', 20);
        $this->assertSame(1, PrayerLog::query()->count());
    }

    public function test_invalid_input_returns_validation_errors(): void
    {
        $this->api()->postJson('/api/v1/prayer-logs', $this->payload([
            'source' => 'web',
            'status' => 'great',
            'metrics' => ['rakaat' => 0, 'ruku' => 41, 'sujud' => 81, 'duration_seconds' => 10, 'stillness' => 1.5,
                'started_at' => '2026-03-10T13:05:00+01:00', 'ended_at' => '2026-03-10T13:00:00+01:00'],
        ]))
            ->assertUnprocessable()
            ->assertJsonStructure(['message', 'errors'])
            ->assertJsonValidationErrors(['source', 'status', 'metrics.rakaat', 'metrics.ruku', 'metrics.sujud',
                'metrics.duration_seconds', 'metrics.stillness', 'metrics.ended_at']);

        $this->api()->postJson('/api/v1/prayer-logs', $this->payload(['prayer_date' => '2026-03-11']))
            ->assertUnprocessable()->assertJsonValidationErrors('prayer_date');
        $this->assertDatabaseCount('prayer_logs', 0);
    }

    public function test_logs_are_read_by_date_range_up_to_92_days(): void
    {
        PrayerLog::factory()->for($this->user)->create(['prayer_date' => '2026-03-09', 'prayer' => 'isha', 'hasanat' => 10]);
        PrayerLog::factory()->for($this->user)->create(['prayer_date' => '2026-03-09', 'prayer' => 'fajr', 'hasanat' => 4]);
        PrayerLog::factory()->for($this->user)->create(['prayer_date' => '2026-01-01', 'prayer' => 'fajr']);
        PrayerLog::factory()->create(['prayer_date' => '2026-03-09']);   // someone else's

        $this->api()->getJson('/api/v1/prayer-logs?from=2026-03-01&to=2026-03-10')
            ->assertOk()
            ->assertJsonCount(2, 'data')
            ->assertJsonPath('data.0.prayer', 'fajr')
            ->assertJsonPath('data.1.prayer', 'isha')
            ->assertJsonPath('meta.total_hasanat', 14);

        $this->api()->getJson('/api/v1/prayer-logs?from=2025-12-09&to=2026-03-10')->assertOk();   // exactly 92 days
        $this->api()->getJson('/api/v1/prayer-logs?from=2025-12-08&to=2026-03-10')
            ->assertUnprocessable()->assertJsonValidationErrors('to');
        $this->api()->getJson('/api/v1/prayer-logs?from=2026-03-10&to=2026-03-01')
            ->assertUnprocessable()->assertJsonValidationErrors('from');
    }

    public function test_the_summary_adds_up(): void
    {
        foreach (['2026-03-09', '2026-03-10'] as $date) {
            foreach (PrayerLog::PRAYERS as $prayer) {
                $this->api()->postJson('/api/v1/prayer-logs', [
                    'prayer_date' => $date, 'prayer' => $prayer, 'status' => 'on_time', 'place' => 'home', 'source' => 'android',
                ])->assertSuccessful();
            }
        }
        $this->api()->postJson('/api/v1/prayer-logs', [
            'prayer_date' => '2026-03-08', 'prayer' => 'fajr', 'status' => 'missed', 'source' => 'android',
        ])->assertCreated();

        $this->api()->getJson('/api/v1/me/summary')
            ->assertOk()
            ->assertJsonPath('data.timezone', 'Europe/Paris')
            // Day 1: 5 × (10 + 1 streak); day 2: 5 × (10 + 2 streak); the missed Fajr: 0.
            ->assertJsonPath('data.total_hasanat', 55 + 60)
            ->assertJsonPath('data.prayers_logged', 11)
            ->assertJsonPath('data.prayers_prayed', 10)
            ->assertJsonPath('data.streak.current', 2)
            ->assertJsonPath('data.streak.best', 2)
            ->assertJsonPath('data.today.date', '2026-03-10')
            ->assertJsonPath('data.today.prayed', 5)
            ->assertJsonPath('data.today.hasanat', 60)
            ->assertJsonPath('data.today.logs.isha.source', 'android');
    }
}
