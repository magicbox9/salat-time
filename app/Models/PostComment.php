<?php

namespace App\Models;

use Database\Factories\PostCommentFactory;
use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\SoftDeletes;

#[Fillable(['post_id', 'user_id', 'body', 'hidden_at', 'hidden_by'])]
class PostComment extends Model
{
    /** @use HasFactory<PostCommentFactory> */
    use HasFactory, SoftDeletes;

    protected function casts(): array
    {
        return ['hidden_at' => 'datetime'];
    }

    public function post(): BelongsTo
    {
        return $this->belongsTo(MosquePost::class, 'post_id');
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }
}
