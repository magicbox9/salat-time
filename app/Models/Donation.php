<?php

namespace App\Models;

use Database\Factories\DonationFactory;
use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Attributes\Hidden;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/** A donation to a campaign, paid to the mosque by PayPal or bank transfer. Amount in cents. */
#[Fillable(['campaign_id', 'mosque_id', 'user_id', 'donor_name', 'donor_email', 'anonymous', 'message', 'amount',
    'currency', 'method', 'reference'])]
#[Hidden(['donor_email', 'provider_payload'])]
class Donation extends Model
{
    /** @use HasFactory<DonationFactory> */
    use HasFactory;

    public const METHODS = ['paypal', 'bank'];

    public const STATUSES = ['pending', 'completed', 'cancelled', 'failed', 'refunded'];

    protected function casts(): array
    {
        return [
            'anonymous' => 'boolean',
            'amount' => 'integer',
            'confirmed_at' => 'datetime',
            'provider_payload' => 'array',
        ];
    }

    public function campaign(): BelongsTo
    {
        return $this->belongsTo(Campaign::class);
    }

    public function mosque(): BelongsTo
    {
        return $this->belongsTo(Mosque::class);
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }
}
