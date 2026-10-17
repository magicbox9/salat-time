<?php

namespace Tests\Feature\Display;

use App\Models\Mosque;
use App\Models\User;

/** People and mosques the display tests share. */
trait DisplayFixtures
{
    protected function mosque(): Mosque
    {
        return Mosque::factory()->withCalendar()->create(['timezone' => 'Europe/Paris']);
    }

    protected function managerOf(Mosque $mosque): User
    {
        $user = User::factory()->create();
        $mosque->managers()->attach($user, ['role' => 'owner']);

        return $user;
    }

    protected function admin(): User
    {
        $user = User::factory()->create();
        $user->forceFill(['is_admin' => true])->save();

        return $user;
    }
}
