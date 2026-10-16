<?php

namespace Tests\Feature\Api;

use App\Models\Mosque;
use App\Models\PrayerLog;
use App\Models\User;
use Carbon\CarbonImmutable;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

/** API v1: timestamp format, the person's language, and web edits of phone logs. */
class CompanionApiHardeningTest extends TestCase
{
    use RefreshDatabase;

    private User $user;

    private string $token;

    protected function setUp(): void
    {
        parent::setUp();
        $this->withoutVite();
        // Tuesday 10 March 2026, 14:00 in Paris.
        $this->travelTo(CarbonImmutable::parse('2026-03-10 14:00', 'Europe/Paris'));
        $this->user = User::factory()->create();
        $this->token = $this->user->createToken('iPhone', ['prayers:read', 'prayers:write'])->plainTextToken;
    }

    private function api(): static
    {
        return $this->withToken($this->token)->withHeader('X-Timezone', 'Europe/Paris');
    }

    /** @return array<string, mixed> */
    private function payload(array $metrics = [], array $overrides = []): array
    {
        return [
            'prayer_date' => '2026-03-10',
            'prayer' => 'dhuhr',
            'status' => 'on_time',
            'place' => 'home',
            'source' => 'android',
            'metrics' => $metrics,
            ...$overrides,
        ];
    }

    public function test_timestamps_must_be_iso_8601_with_an_offset(): void
    {
        $this->api()->postJson('/api/v1/prayer-logs', $this->payload(
            ['started_at' => '2026-03-10 13:05:00', 'ended_at' => '10 March 2026 13:12'],
            ['prayed_at' => 'March 10, 2026'],
        ))
            ->assertUnprocessable()
            ->assertJsonValidationErrors(['prayed_at', 'metrics.started_at', 'metrics.ended_at']);

        $this->assertDatabaseCount('prayer_logs', 0);
    }

    public function test_timestamps_are_stored_and_returned_in_utc(): void
    {
        $this->api()->postJson('/api/v1/prayer-logs', $this->payload([
            'rakaat' => 4,
            'started_at' => '2026-03-10T13:05:00+01:00',
            'ended_at' => '2026-03-10T12:12:30.123456789Z',
            'unknown_sensor' => 'ignored',
        ]))
            ->assertCreated()
            ->assertJsonPath('data.metrics.started_at', '2026-03-10T12:05:00+00:00')
            ->assertJsonPath('data.metrics.ended_at', '2026-03-10T12:12:30+00:00')
            ->assertJsonPath('data.prayed_at', '2026-03-10T12:05:00+00:00')
            ->assertJsonMissingPath('data.metrics.unknown_sensor');
    }

    public function test_messages_follow_the_account_language(): void
    {
        $this->user->forceFill(['locale' => 'fr'])->save();

        $this->api()->getJson('/api/v1/me/mosque/times')
            ->assertNotFound()
            ->assertJsonPath('code', 'no_mosque')
            ->assertJsonPath('message', 'Aucune mosquée choisie. Désignez votre mosquée sur le site.');
    }

    public function test_messages_follow_accept_language_without_an_account_language(): void
    {
        $this->api()->withHeader('Accept-Language', 'ar-MA,ar;q=0.9')
            ->postJson('/api/v1/prayer-logs', $this->payload([], ['prayer_date' => '2026-03-11']))
            ->assertUnprocessable()
            ->assertJsonPath('errors.prayer_date.0', 'لا يمكن تسجيل صلاة في يوم لم يأتِ بعد.');

        // No language asked for: English.
        $this->flushHeaders()->api()->getJson('/api/v1/me/mosque/times')
            ->assertJsonPath('message', 'No mosque chosen yet. Mark a mosque as your own on the website.');
    }

    public function test_a_web_edit_keeps_the_mosque_the_phone_recorded(): void
    {
        $own = Mosque::factory()->create(['timezone' => 'Europe/Paris']);
        $this->user->favoriteMosques()->attach($own->id, ['is_primary' => true]);
        $visited = Mosque::factory()->create(['timezone' => 'Europe/Paris']);

        $this->api()->postJson('/api/v1/prayer-logs', $this->payload(
            ['rakaat' => 4, 'stillness' => 1],
            ['place' => 'mosque', 'mosque_id' => $visited->id],
        ))->assertCreated()->assertJsonPath('data.mosque_id', $visited->id);

        // The web form never names a mosque: congregation added, the mosque and sensors stay.
        $this->app['auth']->forgetGuards();
        $this->actingAs($this->user)->post('/prayers/logs', [
            'prayer_date' => '2026-03-10', 'prayer' => 'dhuhr', 'status' => 'on_time',
            'place' => 'mosque', 'in_congregation' => true,
        ])->assertSessionHasNoErrors();

        $log = PrayerLog::query()->sole();
        $this->assertSame($visited->id, $log->mosque_id);
        $this->assertSame('android', $log->source);
        $this->assertSame(4, $log->metrics['rakaat']);
        // 10 on time + 5 mosque + 5 congregation + 5 khushu + 3 rakaat.
        $this->assertSame(28, $log->hasanat);

        // Moving it home drops the mosque.
        $this->actingAs($this->user)->post('/prayers/logs', [
            'prayer_date' => '2026-03-10', 'prayer' => 'dhuhr', 'status' => 'on_time', 'place' => 'home',
        ])->assertSessionHasNoErrors();
        $this->assertNull($log->refresh()->mosque_id);
    }
}
