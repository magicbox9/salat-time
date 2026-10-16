<?php

namespace Database\Factories;

use App\Models\Mosque;
use App\Models\MosqueClaim;
use App\Models\User;
use Illuminate\Database\Eloquent\Factories\Factory;

/** @extends Factory<MosqueClaim> */
class MosqueClaimFactory extends Factory
{
    public function definition(): array
    {
        return [
            'mosque_id' => Mosque::factory(),
            'user_id' => User::factory(),
            'status' => MosqueClaim::PENDING,
            'role_at_mosque' => 'Président de l\'association',
            'phone' => fake()->phoneNumber(),
            'message' => fake()->sentence(),
        ];
    }
}
