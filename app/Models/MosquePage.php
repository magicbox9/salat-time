<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\SoftDeletes;

/** A static page of a mosque's site (About us, Courses, …). Body is Markdown. */
#[Fillable(['mosque_id', 'author_id', 'title', 'slug', 'body', 'sort', 'show_in_menu', 'published_at'])]
class MosquePage extends Model
{
    use SoftDeletes;

    protected function casts(): array
    {
        return ['show_in_menu' => 'boolean', 'published_at' => 'datetime'];
    }

    public function mosque(): BelongsTo
    {
        return $this->belongsTo(Mosque::class);
    }

    public function author(): BelongsTo
    {
        return $this->belongsTo(User::class, 'author_id');
    }
}
