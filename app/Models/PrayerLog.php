<?php

namespace App\Models;

use Database\Factories\PrayerLogFactory;
use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/** One prayer in the personal tracker. */
#[Fillable(['user_id', 'prayer_date', 'prayer', 'status', 'prayed_at', 'place', 'mosque_id', 'in_congregation',
    'source', 'metrics', 'hasanat'])]
class PrayerLog extends Model
{
    /** @use HasFactory<PrayerLogFactory> */
    use HasFactory;

    public const PRAYERS = ['fajr', 'dhuhr', 'asr', 'maghrib', 'isha'];

    public const STATUSES = ['on_time', 'late', 'qada', 'missed'];

    public const PLACES = ['mosque', 'home', 'work', 'other'];

    public const SOURCES = ['web', 'ios', 'android'];

    protected function casts(): array
    {
        return [
            'prayer_date' => 'date',
            'prayed_at' => 'datetime',
            'in_congregation' => 'boolean',
            'metrics' => 'array',
        ];
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    public function mosque(): BelongsTo
    {
        return $this->belongsTo(Mosque::class);
    }
}
