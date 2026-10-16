<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/** The look and behaviour of a mosque's full-screen display. */
#[Fillable(['mosque_id', 'settings', 'adhan_audio_path', 'updated_by'])]
class MosqueDisplaySetting extends Model
{
    protected function casts(): array
    {
        return ['settings' => 'array'];
    }

    public function mosque(): BelongsTo
    {
        return $this->belongsTo(Mosque::class);
    }
}
