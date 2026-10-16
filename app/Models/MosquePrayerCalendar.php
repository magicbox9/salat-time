<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/**
 * A mosque's published calendar for one year.
 *
 * @property array<int, array<int, array<int, string>>> $days  12 months × days × 6 times
 * @property array<int, array<int, array<int, string>>>|null $iqama  12 months × days × 5 values
 */
#[Fillable(['mosque_id', 'year', 'source', 'timezone', 'days', 'iqama', 'imsak_minutes', 'retrieved_at'])]
class MosquePrayerCalendar extends Model
{
    protected function casts(): array
    {
        return [
            'days' => 'array',
            'iqama' => 'array',
            'retrieved_at' => 'datetime',
        ];
    }

    public function mosque(): BelongsTo
    {
        return $this->belongsTo(Mosque::class);
    }
}
