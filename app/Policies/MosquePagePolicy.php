<?php

namespace App\Policies;

use App\Models\MosquePage;
use App\Models\User;

/** A site page belongs to its mosque: whoever manages the mosque manages its pages. */
class MosquePagePolicy
{
    public function update(User $user, MosquePage $page): bool
    {
        return $this->managesMosqueOf($user, (int) $page->mosque_id);
    }

    public function delete(User $user, MosquePage $page): bool
    {
        return $this->managesMosqueOf($user, (int) $page->mosque_id);
    }

    private function managesMosqueOf(User $user, int $mosqueId): bool
    {
        return $user->is_admin || $user->managedMosques()->whereKey($mosqueId)->exists();
    }
}
