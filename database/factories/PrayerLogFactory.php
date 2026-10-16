<?php

namespace Database\Factories;

use App\Models\PrayerLog;
use App\Models\User;
use Illuminate\Database\Eloquent\Factories\Factory;

/** @extends Factory<PrayerLog> */
class PrayerLogFactory extends Factory
{
    public function definition(): array
    {
        return [
            'user_id' => User::factory(),
            'prayer_date' => now()->toDateString(),
            'prayer' => 'fajr',
            'status' => 'on_time',
            'place' => 'home',
            'source' => 'web',
        ];
    }
}
