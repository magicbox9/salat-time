<?php

namespace Tests\Feature\Admin;

use App\Models\User;

trait CreatesAdmins
{
    /** is_admin is not mass-assignable, exactly like in the app. */
    protected function createAdmin(array $attributes = []): User
    {
        $admin = User::factory()->create($attributes);
        $admin->forceFill(['is_admin' => true])->save();

        return $admin;
    }
}
