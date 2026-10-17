<?php

namespace Tests\Feature\Discover;

use App\Models\Mosque;
use App\Models\User;
use App\Services\PrayerTimes\MosqueTimetable;
use Carbon\CarbonImmutable;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class NearbyMosquesTest extends TestCase
{
    use RefreshDatabase;

    // Notre-Dame de Paris.
    private const LAT = 48.8530;

    private const LNG = 2.3499;

    public function test_mosques_come_nearest_first_with_the_presenter_fields(): void
    {
        $far = Mosque::factory()->at(48.8800, 2.3499)->create();       // ~3 km
        $near = Mosque::factory()->withCalendar()->at(48.8540, 2.3499)->create();   // ~110 m
        Mosque::factory()->at(45.7640, 4.8357)->create();             // Lyon: far away

        $response = $this->getJson('/mosques/near.json?lat='.self::LAT.'&lng='.self::LNG)->assertOk();

        $response->assertJsonPath('mosques.0.id', $near->id)
            ->assertJsonPath('mosques.1.id', $far->id)
            ->assertJsonCount(2, 'mosques')
            ->assertJsonPath('origin', ['lat' => self::LAT, 'lng' => self::LNG])
            ->assertJsonStructure(['radius_km', 'mosques' => [[
                'id', 'slug', 'name', 'address', 'postcode', 'city', 'country_code', 'lat', 'lng', 'timezone',
                'distance_m', 'has_times', 'verified', 'source', 'logo_url', 'mawaqit_url', 'google_maps_url',
                'is_favorite', 'is_primary', 'today', 'tomorrow',
            ]]])
            ->assertJsonPath('mosques.0.has_times', true)
            ->assertJsonPath('mosques.1.has_times', false)
            ->assertJsonPath('mosques.1.today.source', 'calculated')
            ->assertJsonPath('mosques.0.today.source', null)
            ->assertJsonPath('mosques.0.is_favorite', false);

        $this->assertEqualsWithDelta(111, $response->json('mosques.0.distance_m'), 5);
    }

    public function test_today_and_tomorrow_match_the_published_calendar(): void
    {
        $mosque = Mosque::factory()->withCalendar()->at(48.8540, 2.3499)->create();
        $timetable = app(MosqueTimetable::class);
        $today = CarbonImmutable::now($mosque->timezone);

        $response = $this->getJson('/mosques/near.json?lat='.self::LAT.'&lng='.self::LNG)->assertOk();

        $expectedToday = $timetable->day($mosque, $today);
        $expectedTomorrow = $timetable->day($mosque, $today->addDay());
        $this->assertSame(['date' => $expectedToday['date'], 'times' => $expectedToday['times']], $response->json('mosques.0.today'));
        $this->assertSame(['date' => $expectedTomorrow['date'], 'times' => $expectedTomorrow['times']], $response->json('mosques.0.tomorrow'));
    }

    public function test_the_radius_widens_until_enough_mosques_are_found(): void
    {
        // Three mosques within 5 km, six more between 10 and 25 km.
        foreach ([0.01, 0.02, 0.03] as $offset) {
            Mosque::factory()->at(self::LAT + $offset, self::LNG)->create();
        }
        foreach ([0.12, 0.13, 0.14, 0.15, 0.16, 0.17] as $offset) {
            Mosque::factory()->at(self::LAT + $offset, self::LNG)->create();
        }
        Mosque::factory()->at(self::LAT + 0.35, self::LNG)->create();   // ~39 km

        $this->getJson('/mosques/near.json?lat='.self::LAT.'&lng='.self::LNG)
            ->assertOk()
            ->assertJsonPath('radius_km', 25)
            ->assertJsonCount(9, 'mosques');

        // An explicit radius is used as given.
        $this->getJson('/mosques/near.json?lat='.self::LAT.'&lng='.self::LNG.'&radius=5')
            ->assertOk()
            ->assertJsonPath('radius_km', 5)
            ->assertJsonCount(3, 'mosques');

        // The limit caps the answer.
        $this->getJson('/mosques/near.json?lat='.self::LAT.'&lng='.self::LNG.'&radius=50&limit=4')
            ->assertOk()
            ->assertJsonCount(4, 'mosques');
    }

    public function test_a_dense_area_stays_within_five_kilometres(): void
    {
        for ($i = 1; $i <= 8; $i++) {
            Mosque::factory()->at(self::LAT + $i * 0.002, self::LNG)->create();
        }
        Mosque::factory()->at(self::LAT + 0.08, self::LNG)->create();   // ~9 km

        $this->getJson('/mosques/near.json?lat='.self::LAT.'&lng='.self::LNG)
            ->assertOk()
            ->assertJsonPath('radius_km', 5)
            ->assertJsonCount(8, 'mosques');
    }

    public function test_signed_in_visitors_see_which_mosques_they_saved(): void
    {
        $user = User::factory()->create();
        $mine = Mosque::factory()->at(48.8540, 2.3499)->create();
        $saved = Mosque::factory()->at(48.8560, 2.3499)->create();
        Mosque::factory()->at(48.8580, 2.3499)->create();
        $user->favoriteMosques()->attach([$mine->id => ['is_primary' => true], $saved->id => ['is_primary' => false]]);

        $this->actingAs($user)
            ->getJson('/mosques/near.json?lat='.self::LAT.'&lng='.self::LNG)
            ->assertOk()
            ->assertJsonPath('mosques.0.is_favorite', true)
            ->assertJsonPath('mosques.0.is_primary', true)
            ->assertJsonPath('mosques.1.is_favorite', true)
            ->assertJsonPath('mosques.1.is_primary', false)
            ->assertJsonPath('mosques.2.is_favorite', false);
    }

    public function test_coordinates_radius_and_limit_are_validated(): void
    {
        $this->getJson('/mosques/near.json')->assertJsonValidationErrors(['lat', 'lng']);
        $this->getJson('/mosques/near.json?lat=91&lng=0')->assertJsonValidationErrors('lat');
        $this->getJson('/mosques/near.json?lat=0&lng=-181')->assertJsonValidationErrors('lng');
        $this->getJson('/mosques/near.json?lat=0&lng=0&radius=51')->assertJsonValidationErrors('radius');
        $this->getJson('/mosques/near.json?lat=0&lng=0&radius=0.5')->assertJsonValidationErrors('radius');
        $this->getJson('/mosques/near.json?lat=0&lng=0&limit=51')->assertJsonValidationErrors('limit');
        $this->getJson('/mosques/near.json?lat=abc&lng=0')->assertJsonValidationErrors('lat');
    }
}
