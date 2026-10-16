<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Attributes\Hidden;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/**
 * Where a mosque receives donations: its own PayPal account or bank account.
 * The platform never holds the money. Verified by an admin before use.
 */
#[Fillable(['mosque_id', 'type', 'paypal_email', 'paypal_merchant_id', 'account_holder', 'iban', 'bic', 'bank_name'])]
#[Hidden(['iban'])]
class MosquePayoutMethod extends Model
{
    public const TYPES = ['paypal', 'bank'];

    protected function casts(): array
    {
        return ['iban' => 'encrypted', 'verified_at' => 'datetime'];
    }

    public function mosque(): BelongsTo
    {
        return $this->belongsTo(Mosque::class);
    }

    public function isVerified(): bool
    {
        return $this->verified_at !== null;
    }

    /** "FR76 •••• •••• 1234" for display. */
    public function maskedIban(): ?string
    {
        if (! $this->iban) {
            return null;
        }
        $iban = preg_replace('/\s+/', '', $this->iban);

        return substr($iban, 0, 4).' •••• •••• '.substr($iban, -4);
    }
}
