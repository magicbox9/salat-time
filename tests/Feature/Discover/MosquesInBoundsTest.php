<?php

namespace Tests\Feature\Discover;

use App\Http\Controllers\Discover\MosquesInBoundsController;
use App\Models\Mosque;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Tests\TestCase;

class MosquesInBoundsTest extends TestCase
{
    use RefreshDatabase;

    public function test_it_returns_the_mosques_inside_the_box_with_minimal_fields(): void
    {
        $inside = Mosque::factory()->withCalendar()->at(48.86, 2.35)->create();
        $alsoInside = Mosque::factory()->at(48.80, 2.20)->create();
        Mosque::factory()->at(48.86, 2.60)->create();   // east of the box
        Mosque::factory()->at(49.10, 2.35)->create();   // north of the box

        $response = $this->getJson('/mosques/in-bounds.json?w=2.1&s=48.7&e=2.5&n=49')->assertOk();

        $response->assertJsonPath('truncated', false)->assertJsonCount(2, 'mosques');
        $this->assertEqualsCanonicalizing([$inside->id, $alsoInside->id], array_column($response->json('mosques'), 'id'));
        $this->assertSame(['id', 'slug', 'name', 'city', 'lat', 'lng', 'has_times'], array_keys($response->json('mosques.0')));
        // Mosques that publish times come first.
        $response->assertJsonPath('mosques.0.id', $inside->id)->assertJsonPath('mosques.0.has_times', true);
    }

    public function test_a_box_across_the_antimeridian_works(): void
    {
        $east = Mosque::factory()->at(-16.5, 179.5)->create();
        $west = Mosque::factory()->at(-16.5, -179.5)->create();
        Mosque::factory()->at(-16.5, 177.0)->create();

        $response = $this->getJson('/mosques/in-bounds.json?w=179&s=-17&e=-179&n=-16')->assertOk();

        $this->assertEqualsCanonicalizing([$east->id, $west->id], array_column($response->json('mosques'), 'id'));
    }

    public function test_the_answer_is_capped_at_five_hundred_mosques(): void
    {
        $rows = [];
        for ($i = 0; $i <= MosquesInBoundsController::MAX_ROWS; $i++) {
            $rows[] = [
                'slug' => 'mosquee-'.$i,
                'name' => 'Mosquée '.$i,
                'search_name' => 'mosquee '.$i,
                'latitude' => 48.5 + $i * 0.0005,
                'longitude' => 2.3,
                'source' => 'osm',
            ];
        }
        DB::table('mosques')->insert($rows);

        $this->getJson('/mosques/in-bounds.json?w=2&s=48.4&e=2.6&n=48.9')
            ->assertOk()
            ->assertJsonPath('truncated', true)
            ->assertJsonCount(MosquesInBoundsController::MAX_ROWS, 'mosques');
    }

    public function test_the_box_is_validated_and_limited_to_about_two_degrees(): void
    {
        $this->getJson('/mosques/in-bounds.json')->assertJsonValidationErrors(['w', 's', 'e', 'n']);
        $this->getJson('/mosques/in-bounds.json?w=0&s=40&e=5&n=42')->assertJsonValidationErrors('bounds');
        $this->getJson('/mosques/in-bounds.json?w=0&s=40&e=1&n=43')->assertJsonValidationErrors('bounds');
        $this->getJson('/mosques/in-bounds.json?w=0&s=42&e=1&n=41')->assertJsonValidationErrors('bounds');
        $this->getJson('/mosques/in-bounds.json?w=0&s=91&e=1&n=92')->assertJsonValidationErrors(['s', 'n']);
        $this->getJson('/mosques/in-bounds.json?w=-200&s=40&e=1&n=41')->assertJsonValidationErrors('w');
    }
}
