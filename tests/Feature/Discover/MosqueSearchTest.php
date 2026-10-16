<?php

namespace Tests\Feature\Discover;

use App\Http\Controllers\Discover\MosqueSearchController;
use App\Models\Mosque;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class MosqueSearchTest extends TestCase
{
    use RefreshDatabase;

    public function test_it_finds_mosques_by_name_or_city_ignoring_accents(): void
    {
        $evry = Mosque::factory()->withCalendar()->create(['name' => 'Grande Mosquée d’Évry', 'city' => 'Évry-Courcouronnes']);
        Mosque::factory()->create(['name' => 'Mosquée Al Nour', 'city' => 'Lille']);

        $this->getJson('/mosques/search.json?q=evry')
            ->assertOk()
            ->assertJsonCount(1, 'mosques')
            ->assertJsonPath('mosques.0.id', $evry->id)
            ->assertJsonPath('mosques.0.has_times', true)
            ->assertJsonStructure(['mosques' => [['slug', 'name', 'city', 'lat', 'lng', 'google_maps_url']]]);

        $this->getJson('/mosques/search.json?q=Lille')
            ->assertOk()
            ->assertJsonPath('mosques.0.name', 'Mosquée Al Nour');
    }

    public function test_results_are_limited(): void
    {
        Mosque::factory()->count(MosqueSearchController::LIMIT + 3)->create(['city' => 'Marseille']);

        $this->getJson('/mosques/search.json?q=marseille')
            ->assertOk()
            ->assertJsonCount(MosqueSearchController::LIMIT, 'mosques');
    }

    public function test_the_query_is_validated(): void
    {
        $this->getJson('/mosques/search.json')->assertJsonValidationErrors('q');
        $this->getJson('/mosques/search.json?q=a')->assertJsonValidationErrors('q');
        $this->getJson('/mosques/search.json?q='.str_repeat('a', 101))->assertJsonValidationErrors('q');
    }

    public function test_text_without_letters_or_digits_matches_no_mosque(): void
    {
        Mosque::factory()->count(3)->create();

        // Emoji and symbols vanish from the search key; they must not match everything.
        $this->getJson('/mosques/search.json?q='.urlencode('🕌🕌'))->assertOk()->assertExactJson(['mosques' => []]);
        $this->getJson('/mosques/search.json?q='.urlencode('%%'))->assertOk()->assertJsonCount(0, 'mosques');
    }

    public function test_arabic_names_can_be_searched(): void
    {
        $mosque = Mosque::factory()->create(['name' => 'مسجد النور', 'city' => 'Toul']);

        $this->getJson('/mosques/search.json?q='.urlencode('مسجد النور'))
            ->assertOk()
            ->assertJsonPath('mosques.0.id', $mosque->id);
    }
}
