<?php

namespace Database\Factories;

use App\Models\Mosque;
use App\Models\MosquePost;
use Illuminate\Database\Eloquent\Factories\Factory;

/** @extends Factory<MosquePost> */
class MosquePostFactory extends Factory
{
    public function definition(): array
    {
        return [
            'mosque_id' => Mosque::factory(),
            'type' => 'news',
            'title' => fake()->sentence(5),
            'body' => fake()->paragraphs(2, true),
            'published_at' => now(),
        ];
    }
}
