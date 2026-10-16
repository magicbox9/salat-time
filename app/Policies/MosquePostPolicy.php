<?php

namespace App\Policies;

use App\Models\MosquePost;
use App\Models\User;

/** Posts belong to their mosque: whoever manages the mosque manages its posts. */
class MosquePostPolicy
{
    public function update(User $user, MosquePost $post): bool
    {
        return $this->managesMosqueOf($user, $post);
    }

    public function delete(User $user, MosquePost $post): bool
    {
        return $this->managesMosqueOf($user, $post);
    }

    private function managesMosqueOf(User $user, MosquePost $post): bool
    {
        return $user->is_admin || $user->managedMosques()->whereKey($post->mosque_id)->exists();
    }
}
