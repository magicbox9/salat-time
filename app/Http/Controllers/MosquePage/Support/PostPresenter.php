<?php

namespace App\Http\Controllers\MosquePage\Support;

use App\Models\MosquePost;
use App\Models\PostComment;
use App\Models\User;
use Carbon\CarbonInterface;

/** JSON shapes for posts and comments (TS types in components/mosque/types.ts). */
class PostPresenter
{
    /** @return array<string, mixed> */
    public static function post(MosquePost $post): array
    {
        return [
            'id' => $post->id,
            'type' => $post->type,
            'title' => $post->title,
            'body' => $post->body,
            'image_url' => self::url($post->image_path),
            'event_starts_at' => self::iso($post->event_starts_at),
            'pinned' => (bool) $post->pinned,
            'published_at' => self::iso($post->published_at),
            'comments_count' => (int) ($post->comments_count ?? 0),
        ];
    }

    /** @return array<string, mixed> */
    public static function comment(PostComment $comment, ?User $viewer, bool $moderator): array
    {
        $author = $comment->user;

        return [
            'id' => $comment->id,
            'body' => $comment->body,
            'author' => $author instanceof User ? $author->name : '',
            'created_at' => self::iso($comment->created_at),
            'hidden' => $comment->hidden_at !== null,
            'mine' => $viewer !== null && $viewer->id === $comment->user_id,
            'can_delete' => $viewer !== null && ($viewer->id === $comment->user_id || $viewer->is_admin),
            'can_moderate' => $moderator,
        ];
    }

    public static function iso(mixed $date): ?string
    {
        return $date instanceof CarbonInterface ? $date->toIso8601String() : null;
    }

    public static function url(?string $path): ?string
    {
        return $path ? asset('storage/'.$path) : null;
    }
}
