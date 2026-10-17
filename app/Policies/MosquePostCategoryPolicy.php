<?php

namespace App\Policies;

use App\Models\MosquePostCategory;
use App\Models\User;

/** A blog category belongs to its mosque: whoever manages the mosque manages its categories. */
class MosquePostCategoryPolicy
{
    public function update(User $user, MosquePostCategory $category): bool
    {
        return $this->managesMosqueOf($user, (int) $category->mosque_id);
    }

    public function delete(User $user, MosquePostCategory $category): bool
    {
        return $this->managesMosqueOf($user, (int) $category->mosque_id);
    }

    private function managesMosqueOf(User $user, int $mosqueId): bool
    {
        return $user->is_admin || $user->managedMosques()->whereKey($mosqueId)->exists();
    }
}
