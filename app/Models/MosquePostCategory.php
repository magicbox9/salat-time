<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

/** A blog category of a mosque's site (Khutbah, News, Events, …). */
#[Fillable(['mosque_id', 'name', 'slug', 'description', 'sort'])]
class MosquePostCategory extends Model
{
    public function mosque(): BelongsTo
    {
        return $this->belongsTo(Mosque::class);
    }

    public function posts(): HasMany
    {
        return $this->hasMany(MosquePost::class, 'category_id');
    }
}
