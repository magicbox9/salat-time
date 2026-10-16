<?php

namespace Database\Factories;

use App\Models\Campaign;
use App\Models\Donation;
use Illuminate\Database\Eloquent\Factories\Factory;
use Illuminate\Support\Str;

/** @extends Factory<Donation> */
class DonationFactory extends Factory
{
    public function definition(): array
    {
        return [
            'campaign_id' => Campaign::factory(),
            'mosque_id' => fn (array $a) => Campaign::query()->find($a['campaign_id'])?->mosque_id,
            'donor_name' => fake()->name(),
            'donor_email' => fake()->safeEmail(),
            'amount' => 5000,
            'currency' => 'EUR',
            'method' => 'bank',
            'reference' => 'DON-'.Str::upper(Str::random(8)),
        ];
    }
}
