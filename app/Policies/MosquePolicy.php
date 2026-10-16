<?php

namespace App\Policies;

use App\Models\Mosque;
use App\Models\User;

/**
 * Who may run a mosque's page. Rights come from the database only:
 * `users.is_admin` or a row in `mosque_managers` (granted after a claim).
 */
class MosquePolicy
{
    /** Edit the page details, publish posts and moderate comments. */
    public function manage(User $user, Mosque $mosque): bool
    {
        return $user->is_admin || $user->manages($mosque);
    }
}
