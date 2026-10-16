<?php

namespace Tests\Feature\Discover;

use App\Models\GeocodeCache;
use App\Services\Geocoding\Providers\NominatimProvider;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\Client\Request;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Http;
use Tests\TestCase;

class GeocodingTest extends TestCase
{
    use RefreshDatabase;

    private const BAN_ANSWER = [
        'type' => 'FeatureCollection',
        'features' => [
            [
                'geometry' => ['type' => 'Point', 'coordinates' => [2.381633, 48.856892]],
                'properties' => ['label' => 'Boulevard Voltaire 75011 Paris', 'type' => 'street', 'postcode' => '75011', 'city' => 'Paris', 'citycode' => '75111'],
            ],
            [
                'geometry' => ['type' => 'Point', 'coordinates' => [55.444588, -20.909778]],
                'properties' => ['label' => 'Saint-Denis', 'type' => 'municipality', 'postcode' => '97400', 'city' => 'Saint-Denis', 'citycode' => '97411'],
            ],
            // Unusable coordinates are dropped.
            ['geometry' => ['coordinates' => ['x', 'y']], 'properties' => ['label' => 'Broken']],
        ],
    ];

    private const NOMINATIM_ANSWER = [[
        'lat' => '50.8467372',
        'lon' => '4.3524932',
        'display_name' => 'Brussels, Brussels-Capital, Belgium',
        'addresstype' => 'city',
        'address' => ['city' => 'Brussels', 'postcode' => '1000', 'country_code' => 'be'],
    ]];

    public function test_french_places_come_from_the_national_address_base(): void
    {
        Http::fake(['data.geopf.fr/*' => Http::response(self::BAN_ANSWER)]);

        $response = $this->getJson('/geocode.json?q=75011&country=FR')->assertOk();

        $response->assertJsonCount(2, 'results')
            ->assertJsonPath('results.0', [
                'label' => 'Boulevard Voltaire 75011 Paris',
                'lat' => 48.856892,
                'lng' => 2.381633,
                'city' => 'Paris',
                'postcode' => '75011',
                'country' => 'FR',
                'kind' => 'street',
            ])
            ->assertJsonPath('results.1.country', 'RE')
            ->assertJsonPath('results.1.kind', 'city');

        Http::assertSent(fn (Request $request) => str_starts_with($request->url(), 'https://data.geopf.fr/geocodage/search')
            && $request['q'] === '75011'
            && (int) $request['limit'] === 6);
    }

    public function test_other_countries_use_nominatim_with_an_identifying_user_agent(): void
    {
        Http::fake(['nominatim.openstreetmap.org/*' => Http::response(self::NOMINATIM_ANSWER)]);

        $this->getJson('/geocode.json?q=Bruxelles&country=be')
            ->assertOk()
            ->assertJsonPath('results.0.label', 'Brussels, Brussels-Capital, Belgium')
            ->assertJsonPath('results.0.city', 'Brussels')
            ->assertJsonPath('results.0.postcode', '1000')
            ->assertJsonPath('results.0.country', 'BE')
            ->assertJsonPath('results.0.kind', 'city');

        Http::assertSent(fn (Request $request) => str_starts_with($request->url(), 'https://nominatim.openstreetmap.org/search')
            && $request['countrycodes'] === 'be'
            && $request['format'] === 'jsonv2'
            && str_starts_with($request->header('User-Agent')[0] ?? '', 'SalatTimeWeb/'));
    }

    public function test_a_question_is_answered_from_the_cache_for_thirty_days(): void
    {
        Http::fake(['data.geopf.fr/*' => Http::response(self::BAN_ANSWER)]);

        $this->getJson('/geocode.json?q=75011&country=FR')->assertOk();
        // Same question, other spacing and case: no second request.
        $this->getJson('/geocode.json?q='.urlencode('  75011 ').'&country=fr')->assertOk()->assertJsonCount(2, 'results');

        Http::assertSentCount(1);
        $this->assertSame(1, GeocodeCache::query()->count());
        $this->assertSame('ban', GeocodeCache::query()->first()->provider);

        // After 30 days the answer is refreshed in place.
        $this->travel(31)->days();
        $this->getJson('/geocode.json?q=75011&country=FR')->assertOk();
        Http::assertSentCount(2);
        $this->assertSame(1, GeocodeCache::query()->count());
    }

    public function test_nominatim_requests_wait_for_their_turn(): void
    {
        Http::fake(['nominatim.openstreetmap.org/*' => Http::response(self::NOMINATIM_ANSWER)]);
        // Another worker sent a request less than a second ago and holds the slot.
        Cache::lock(NominatimProvider::LOCK, 10)->get();

        $this->getJson('/geocode.json?q=Bruxelles&country=BE')
            ->assertStatus(503)
            ->assertJsonPath('results', []);

        Http::assertNothingSent();
        $this->assertSame(0, GeocodeCache::query()->count());
    }

    public function test_a_failing_provider_is_reported_as_unavailable_and_not_cached(): void
    {
        Http::fake(['data.geopf.fr/*' => Http::response('down', 502)]);

        $this->getJson('/geocode.json?q=Lyon&country=FR')
            ->assertStatus(503)
            ->assertJsonStructure(['message', 'results']);

        $this->assertSame(0, GeocodeCache::query()->count());
    }

    public function test_the_query_and_country_are_validated(): void
    {
        Http::fake();

        $this->getJson('/geocode.json?q=ab')->assertJsonValidationErrors('q');
        $this->getJson('/geocode.json?q='.str_repeat('a', 201))->assertJsonValidationErrors('q');
        $this->getJson('/geocode.json?q=Lyon&country=FRA')->assertJsonValidationErrors('country');
        $this->getJson('/geocode.json?q=Lyon&country=F1')->assertJsonValidationErrors('country');

        Http::assertNothingSent();
    }

    public function test_text_the_address_base_would_refuse_is_answered_without_a_request(): void
    {
        Http::fake();

        // The BAN answers 400 to text that does not start with a letter or digit.
        $this->getJson('/geocode.json?q=---&country=FR')->assertOk()->assertExactJson(['results' => []]);
        $this->getJson('/geocode.json?q='.urlencode('-- ab').'&country=FR')->assertOk()->assertJsonPath('results', []);

        Http::assertNothingSent();
    }

    public function test_a_question_the_address_base_refuses_is_an_empty_answer_not_an_outage(): void
    {
        Http::fake(['data.geopf.fr/*' => Http::response(['code' => 400, 'message' => 'Failed parsing query'], 400)]);

        $this->getJson('/geocode.json?q=abc&country=FR')->assertOk()->assertJsonPath('results', []);
    }

    public function test_an_overseas_territory_only_gets_its_own_places(): void
    {
        $feature = fn (string $label, string $citycode, float $lng, float $lat) => [
            'geometry' => ['type' => 'Point', 'coordinates' => [$lng, $lat]],
            'properties' => ['label' => $label, 'type' => 'municipality', 'city' => $label, 'citycode' => $citycode],
        ];
        Http::fake(['data.geopf.fr/*' => Http::response(['type' => 'FeatureCollection', 'features' => [
            $feature('Saint-Pierre', '97225', -61.17, 14.74),   // Martinique
            $feature('Saint-Pierre', '97416', 55.47, -21.34),   // Réunion
            $feature('Saint-Pierre', '97502', -56.17, 46.78),   // Saint-Pierre-et-Miquelon
        ]])]);

        $this->getJson('/geocode.json?q=Saint-Pierre&country=RE')
            ->assertOk()
            ->assertJsonCount(1, 'results')
            ->assertJsonPath('results.0.country', 'RE')
            ->assertJsonPath('results.0.lat', -21.34);

        // Only overseas places are asked for, a full page of them, to filter by territory.
        Http::assertSent(fn (Request $request) => $request['depcode'] === '97' && (int) $request['limit'] === 50);
    }
}
