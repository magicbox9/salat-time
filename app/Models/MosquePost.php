<?php

namespace App\Models;

use Database\Factories\MosquePostFactory;
use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\SoftDeletes;

/** A post on a mosque's page (news, event, announcement, janaza notice). */
#[Fillable(['mosque_id', 'author_id', 'category_id', 'type', 'title', 'slug', 'excerpt', 'body', 'image_path',
    'video_url', 'attachment_path', 'attachment_name', 'event_starts_at', 'pinned', 'published_at'])]
class MosquePost extends Model
{
    /** @use HasFactory<MosquePostFactory> */
    use HasFactory, SoftDeletes;

    public const TYPES = ['news', 'event', 'announcement', 'janaza'];

    protected function casts(): array
    {
        return [
            'event_starts_at' => 'datetime',
            'published_at' => 'datetime',
            'pinned' => 'boolean',
        ];
    }

    public function mosque(): BelongsTo
    {
        return $this->belongsTo(Mosque::class);
    }

    public function author(): BelongsTo
    {
        return $this->belongsTo(User::class, 'author_id');
    }

    public function category(): BelongsTo
    {
        return $this->belongsTo(MosquePostCategory::class, 'category_id');
    }

    public function comments(): HasMany
    {
        return $this->hasMany(PostComment::class, 'post_id');
    }
}
