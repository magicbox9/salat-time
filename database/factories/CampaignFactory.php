<?php

namespace Database\Factories;

use App\Models\Campaign;
use App\Models\Mosque;
use Illuminate\Database\Eloquent\Factories\Factory;
use Illuminate\Support\Str;

/** @extends Factory<Campaign> */
class CampaignFactory extends Factory
{
    public function definition(): array
    {
        $title = 'Agrandissement de la salle de prière '.fake()->unique()->numberBetween(1, 99999);

        return [
            'mosque_id' => Mosque::factory()->verified(),
            'slug' => Str::slug($title),
            'kind' => 'building',
            'title' => $title,
            'summary' => fake()->sentence(12),
            'story' => fake()->paragraphs(3, true),
            'currency' => 'EUR',
            'goal_amount' => 5_000_000,
        ];
    }

    public function active(): static
    {
        return $this->afterMaking(fn (Campaign $c) => $c->forceFill(['status' => 'active', 'starts_at' => now()]))
            ->afterCreating(fn (Campaign $c) => $c->forceFill(['status' => 'active', 'starts_at' => now()])->save());
    }
}
