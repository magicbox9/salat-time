<?php

namespace App\Models;

use Database\Factories\CampaignFactory;
use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\SoftDeletes;

/** A fundraising campaign of a mosque. Amounts are in cents. */
#[Fillable(['mosque_id', 'created_by', 'slug', 'kind', 'title', 'summary', 'story', 'cover_path', 'currency',
    'goal_amount', 'allow_paypal', 'allow_bank', 'show_donor_names', 'starts_at', 'ends_at'])]
class Campaign extends Model
{
    /** @use HasFactory<CampaignFactory> */
    use HasFactory, SoftDeletes;

    public const KINDS = ['building', 'zakat', 'sadaqa', 'iftar', 'education', 'project'];

    public const STATUSES = ['draft', 'pending', 'active', 'completed', 'closed', 'rejected'];

    protected function casts(): array
    {
        return [
            'allow_paypal' => 'boolean',
            'allow_bank' => 'boolean',
            'show_donor_names' => 'boolean',
            'reviewed_at' => 'datetime',
            'starts_at' => 'datetime',
            'ends_at' => 'datetime',
            'goal_amount' => 'integer',
            'raised_amount' => 'integer',
            'pledged_amount' => 'integer',
        ];
    }

    public function getRouteKeyName(): string
    {
        return 'slug';
    }

    public function mosque(): BelongsTo
    {
        return $this->belongsTo(Mosque::class);
    }

    public function donations(): HasMany
    {
        return $this->hasMany(Donation::class);
    }

    public function updates(): HasMany
    {
        return $this->hasMany(CampaignUpdate::class);
    }

    public function isOpen(): bool
    {
        return $this->status === 'active' && (! $this->ends_at || $this->ends_at->isFuture());
    }
}
