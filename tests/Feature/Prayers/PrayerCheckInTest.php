<?php

namespace Tests\Feature\Prayers;

use App\Models\Mosque;
use App\Models\PrayerLog;
use App\Models\User;
use Carbon\CarbonImmutable;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Testing\TestResponse;
use Inertia\Testing\AssertableInertia as Assert;
use Tests\TestCase;

class PrayerCheckInTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        // The page bundle is built by the integrator; tests only need the Inertia payload.
        $this->withoutVite();
        // Tuesday 10 March 2026, 14:00 in Paris (13:00 UTC).
        $this->travelTo(CarbonImmutable::parse('2026-03-10 14:00', 'Europe/Paris'));
    }

    private function withOwnMosque(User $user): Mosque
    {
        $mosque = Mosque::factory()->withCalendar()->create(['timezone' => 'Europe/Paris']);
        $user->favoriteMosques()->attach($mosque->id, ['is_primary' => true]);

        return $mosque;
    }

    private function checkIn(User $user, array $data = []): TestResponse
    {
        return $this->actingAs($user)->post('/prayers/logs', [
            'prayer_date' => '2026-03-10',
            'prayer' => 'fajr',
            'status' => 'on_time',
            'place' => 'home',
            'in_congregation' => false,
            ...$data,
        ]);
    }

    public function test_guests_are_sent_to_login(): void
    {
        $this->get('/prayers')->assertRedirect('/login');
        $this->post('/prayers/logs', [])->assertRedirect('/login');
        $this->assertDatabaseCount('prayer_logs', 0);
    }

    public function test_unverified_users_must_verify_their_email(): void
    {
        $user = User::factory()->unverified()->create();

        $this->actingAs($user)->get('/prayers')->assertRedirect(route('verification.notice'));
        $this->checkIn($user)->assertRedirect(route('verification.notice'));
        $this->assertDatabaseCount('prayer_logs', 0);
    }

    public function test_the_page_shows_a_prompt_without_an_own_mosque(): void
    {
        $user = User::factory()->create();

        $this->actingAs($user)->get('/prayers?tz=Asia/Dubai')
            ->assertOk()
            ->assertInertia(fn (Assert $page) => $page
                ->component('prayers/index')
                ->where('mosque', null)
                ->where('times', null)
                ->where('clock.source', 'device')
                ->where('clock.timezone', 'Asia/Dubai')
                ->has('week', 7)
                ->where('stats.total_hasanat', 0)
                ->has('badges', 6)
                ->has('month.days', 31));
    }

    public function test_the_page_uses_the_own_mosques_published_times(): void
    {
        $user = User::factory()->create();
        $mosque = $this->withOwnMosque($user);

        $this->actingAs($user)->get('/prayers')
            ->assertOk()
            ->assertInertia(fn (Assert $page) => $page
                ->component('prayers/index')
                ->where('mosque.slug', $mosque->slug)
                ->where('clock.source', 'mosque')
                ->where('clock.today', '2026-03-10')
                ->where('clock.editable_from', '2026-03-03')
                ->where('times.today.times.fajr', '06:00')
                ->where('times.today.iqama.isha', '20:40'));
    }

    public function test_a_check_in_is_saved_with_its_hasanat_and_updated_in_place(): void
    {
        $user = User::factory()->create();

        $this->checkIn($user)->assertRedirect()->assertSessionHasNoErrors()
            ->assertInertiaFlash('toast.type', 'success');
        $this->assertDatabaseHas('prayer_logs', [
            'user_id' => $user->id, 'prayer' => 'fajr', 'status' => 'on_time', 'hasanat' => 10, 'source' => 'web',
        ]);

        // Same day and prayer again: the log is changed, not duplicated.
        $this->checkIn($user, ['status' => 'late', 'place' => 'work'])->assertSessionHasNoErrors();
        $this->assertSame(1, PrayerLog::query()->count());
        $this->assertDatabaseHas('prayer_logs', ['user_id' => $user->id, 'status' => 'late', 'place' => 'work', 'hasanat' => 6]);
    }

    public function test_the_mosque_place_defaults_to_the_own_mosque(): void
    {
        $user = User::factory()->create();
        $mosque = $this->withOwnMosque($user);

        $this->checkIn($user, ['place' => 'mosque', 'in_congregation' => true])->assertSessionHasNoErrors();

        // 10 on time + 5 mosque + 7 Fajr in congregation.
        $this->assertDatabaseHas('prayer_logs', ['user_id' => $user->id, 'mosque_id' => $mosque->id, 'hasanat' => 22]);
    }

    public function test_future_days_and_old_days_are_rejected(): void
    {
        $user = User::factory()->create();

        $this->checkIn($user, ['prayer_date' => '2026-03-11'])->assertSessionHasErrors('prayer_date');
        $this->checkIn($user, ['prayer_date' => '2026-03-02'])->assertSessionHasErrors('prayer_date');
        $this->checkIn($user, ['prayer_date' => '2026-03-03'])->assertSessionHasNoErrors();
        $this->assertSame(1, PrayerLog::query()->count());
    }

    public function test_a_prayer_whose_time_has_not_come_is_rejected(): void
    {
        $user = User::factory()->create();
        $this->withOwnMosque($user);   // Isha at 20:30, it is 14:00

        $this->checkIn($user, ['prayer' => 'isha'])->assertSessionHasErrors('prayer');
        $this->checkIn($user, ['prayer' => 'dhuhr'])->assertSessionHasNoErrors();
        $this->assertDatabaseMissing('prayer_logs', ['prayer' => 'isha']);
    }

    public function test_input_is_validated(): void
    {
        $user = User::factory()->create();

        $this->checkIn($user, ['status' => 'perfect'])->assertSessionHasErrors('status');
        $this->checkIn($user, ['prayer' => 'shuruq'])->assertSessionHasErrors('prayer');
        $this->checkIn($user, ['place' => 'moon'])->assertSessionHasErrors('place');
        $this->checkIn($user, ['prayer_date' => '10/03/2026'])->assertSessionHasErrors('prayer_date');
        $this->checkIn($user, ['mosque_id' => 999999])->assertSessionHasErrors('mosque_id');
        $this->assertDatabaseCount('prayer_logs', 0);
    }

    public function test_a_web_check_in_cannot_set_hasanat_or_metrics(): void
    {
        $user = User::factory()->create();

        $this->checkIn($user, ['hasanat' => 9999, 'metrics' => ['stillness' => 1], 'source' => 'ios', 'user_id' => 1])
            ->assertSessionHasNoErrors();

        $log = PrayerLog::query()->sole();
        $this->assertSame($user->id, $log->user_id);
        $this->assertSame(10, $log->hasanat);
        $this->assertNull($log->metrics);
        $this->assertSame('web', $log->source);
    }

    public function test_people_can_only_undo_their_own_check_ins(): void
    {
        $owner = User::factory()->create();
        $other = User::factory()->create();
        $log = PrayerLog::factory()->for($owner)->create(['prayer_date' => '2026-03-10', 'hasanat' => 10]);

        $this->actingAs($other)->delete("/prayers/logs/{$log->id}")->assertForbidden();
        $this->assertModelExists($log);

        $this->actingAs($owner)->delete("/prayers/logs/{$log->id}")->assertRedirect();
        $this->assertModelMissing($log);
    }

    public function test_old_check_ins_cannot_be_undone(): void
    {
        $user = User::factory()->create();
        $log = PrayerLog::factory()->for($user)->create(['prayer_date' => '2026-02-01']);

        $this->actingAs($user)->delete("/prayers/logs/{$log->id}")->assertRedirect();
        $this->assertModelExists($log);
    }

    public function test_complete_days_in_a_row_earn_a_streak_bonus_that_follows_edits(): void
    {
        $user = User::factory()->create();
        foreach (['2026-03-08', '2026-03-09', '2026-03-10'] as $date) {
            foreach (PrayerLog::PRAYERS as $prayer) {
                $this->checkIn($user, ['prayer_date' => $date, 'prayer' => $prayer])->assertSessionHasNoErrors();
            }
        }

        $points = fn (string $date) => (int) PrayerLog::query()->where('prayer_date', $date)->sum('hasanat');
        $this->assertSame(5 * (10 + 1), $points('2026-03-08'));
        $this->assertSame(5 * (10 + 2), $points('2026-03-09'));
        $this->assertSame(5 * (10 + 3), $points('2026-03-10'));

        // Marking a prayer of the middle day as missed breaks the streak after it.
        $this->checkIn($user, ['prayer_date' => '2026-03-09', 'prayer' => 'asr', 'status' => 'missed']);
        $this->assertSame(4 * 10, $points('2026-03-09'));
        $this->assertSame(5 * (10 + 1), $points('2026-03-10'));

        $this->actingAs($user)->get('/prayers')->assertInertia(fn (Assert $page) => $page
            ->where('stats.streak.current', 1)
            ->where('stats.streak.best', 1)
            ->where('today.hasanat', 55)
            ->where('stats.total_hasanat', 55 + 40 + 55));
    }
}
