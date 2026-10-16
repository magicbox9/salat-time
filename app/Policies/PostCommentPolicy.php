<?php

namespace App\Policies;

use App\Models\MosquePost;
use App\Models\PostComment;
use App\Models\User;

/**
 * Authors remove their own comments; a mosque's managers (and admins) hide
 * or restore comments under that mosque's posts.
 */
class PostCommentPolicy
{
    public function delete(User $user, PostComment $comment): bool
    {
        return $user->id === $comment->user_id || $user->is_admin;
    }

    public function moderate(User $user, PostComment $comment): bool
    {
        if ($user->is_admin) {
            return true;
        }

        $mosqueId = MosquePost::withTrashed()->whereKey($comment->post_id)->value('mosque_id');

        return $mosqueId !== null && $user->managedMosques()->whereKey($mosqueId)->exists();
    }
}
