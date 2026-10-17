<?php

namespace Tests\Feature\Mosques;

use App\Models\Mosque;
use App\Models\MosqueClaim;
use App\Models\User;
use App\Support\OsmPlaceOfWorship;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\File;
use Tests\TestCase;

/** OpenStreetMap places tagged religion=muslim that are not mosques stay off the map. */
class OsmPlacesTest extends TestCase
{
    use RefreshDatabase;

    private string $studies;

    protected function setUp(): void
    {
        parent::setUp();
        $this->studies = storage_path('framework/testing/osm-studies-'.uniqid());
        File::ensureDirectoryExists($this->studies.'/study 1/data');
        File::put($this->studies.'/study 1/data/osm_mosques_france.json', json_encode([
            ['osm' => 'node/1', 'lat' => 45.76, 'lon' => 4.83, 'tags' => ['amenity' => 'place_of_worship', 'religion' => 'muslim', 'name' => 'Mosquée A']],
            ['osm' => 'node/2', 'lat' => 45.77, 'lon' => 4.84, 'tags' => ['shop' => 'travel_agency', 'religion' => 'muslim', 'name' => 'Salam Tour']],
            ['osm' => 'node/3', 'lat' => 45.78, 'lon' => 4.85, 'tags' => ['shop' => 'funeral_directors', 'religion' => 'muslim', 'name' => 'Pompes funèbres']],
            ['osm' => 'way/4', 'lat' => 45.79, 'lon' => 4.86, 'tags' => ['building' => 'mosque', 'religion' => 'muslim']],
        ]));
    }

    protected function tearDown(): void
    {
        File::deleteDirectory($this->studies);
        parent::tearDown();
    }

    public function test_only_places_of_worship_are_mosques(): void
    {
        $this->assertTrue(OsmPlaceOfWorship::accepts(['amenity' => 'place_of_worship', 'religion' => 'muslim']));
        $this->assertTrue(OsmPlaceOfWorship::accepts(['amenity' => 'place_of_worship', 'office' => 'association']));
        $this->assertTrue(OsmPlaceOfWorship::accepts(['building' => 'mosque', 'religion' => 'muslim']));

        foreach ([
            ['shop' => 'religion'], ['shop' => 'books', 'building' => 'yes'], ['shop' => 'funeral_directors'],
            ['shop' => 'butcher'], ['shop' => 'travel_agency'], ['amenity' => 'school'], ['amenity' => 'community_centre'],
            ['amenity' => 'grave_yard'], ['office' => 'insurance'], ['building' => 'construction'], [],
            ['building' => 'mosque', 'shop' => 'books'], ['building' => 'mosque', 'landuse' => 'cemetery'],
        ] as $tags) {
            $this->assertFalse(OsmPlaceOfWorship::accepts([...$tags, 'religion' => 'muslim']), json_encode($tags));
        }
    }

    public function test_pruning_removes_places_that_are_not_mosques(): void
    {
        $mosque = $this->osm('node/1', 'Mosquée A');
        $shop = $this->osm('node/2', 'Salam Tour');
        $fan = User::factory()->create();
        $fan->favoriteMosques()->attach($shop->id, ['is_primary' => true]);
        $other = Mosque::factory()->create(['source' => 'mawaqit']);

        $this->artisan('mosques:prune-osm', ['--path' => $this->studies])
            ->expectsOutputToContain('Removed 1 OpenStreetMap places')
            ->assertSuccessful();

        $this->assertModelExists($mosque);
        $this->assertModelExists($other);
        $this->assertModelMissing($shop);
        $this->assertSame(0, $fan->favoriteMosques()->count());
    }

    public function test_a_place_someone_works_on_is_kept_for_review(): void
    {
        $claimed = $this->osm('node/3', 'Pompes funèbres');
        MosqueClaim::factory()->for($claimed)->create();

        $this->artisan('mosques:prune-osm', ['--path' => $this->studies])
            ->expectsOutputToContain('Kept for review')
            ->assertSuccessful();

        $this->assertModelExists($claimed);
    }

    public function test_a_dry_run_removes_nothing(): void
    {
        $shop = $this->osm('node/2', 'Salam Tour');

        $this->artisan('mosques:prune-osm', ['--path' => $this->studies, '--dry-run' => true])
            ->expectsOutputToContain('Would remove: Salam Tour')
            ->assertSuccessful();

        $this->assertModelExists($shop);
    }

    public function test_a_missing_list_fails_without_touching_anything(): void
    {
        $shop = $this->osm('node/2', 'Salam Tour');

        $this->artisan('mosques:prune-osm', ['--path' => $this->studies.'/nowhere'])->assertFailed();

        $this->assertModelExists($shop);
    }

    private function osm(string $ref, string $name): Mosque
    {
        return Mosque::factory()->create(['source' => 'osm', 'osm_ref' => $ref, 'name' => $name]);
    }
}
