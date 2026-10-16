<?php

namespace Database\Factories;

use App\Models\Mosque;
use App\Models\MosquePrayerCalendar;
use Illuminate\Database\Eloquent\Factories\Factory;
use Illuminate\Support\Str;

/** @extends Factory<Mosque> */
class MosqueFactory extends Factory
{
    public function definition(): array
    {
        $city = fake()->city();
        $name = 'Mosquée '.fake()->unique()->lastName();

        return [
            'slug' => Str::slug($name.' '.$city).'-'.fake()->unique()->numberBetween(1, 999999),
            'name' => $name,
            'address' => fake()->streetAddress(),
            'postcode' => fake()->postcode(),
            'city' => $city,
            'country_code' => 'FR',
            'territory' => 'FR',
            'latitude' => fake()->latitude(43, 50),
            'longitude' => fake()->longitude(-1, 7),
            'timezone' => 'Europe/Paris',
            'source' => 'mawaqit',
        ];
    }

    public function at(float $lat, float $lng): static
    {
        return $this->state(fn () => ['latitude' => $lat, 'longitude' => $lng]);
    }

    public function verified(): static
    {
        return $this->state(fn () => ['verified_at' => now()]);
    }

    /** Adds a simple published calendar for the current year (same times every day). */
    public function withCalendar(array $times = ['06:00', '07:30', '13:00', '16:00', '19:00', '20:30']): static
    {
        return $this->afterCreating(function (Mosque $mosque) use ($times) {
            $days = [];
            $iqama = [];
            for ($m = 1; $m <= 12; $m++) {
                $count = (int) date('t', mktime(0, 0, 0, $m, 1, 2024));
                $days[] = array_fill(0, $count, $times);
                $iqama[] = array_fill(0, $count, ['+10', '+10', '+10', '+5', '+10']);
            }
            MosquePrayerCalendar::query()->create([
                'mosque_id' => $mosque->id,
                'year' => (int) now()->year,
                'timezone' => $mosque->timezone,
                'days' => $days,
                'iqama' => $iqama,
            ]);
        });
    }
}
