<?php

namespace App\Models;

use Database\Factories\MosqueClaimFactory;
use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/** A request from a user to manage a mosque's page. */
#[Fillable(['mosque_id', 'user_id', 'status', 'role_at_mosque', 'phone', 'message', 'document_path',
    'reviewed_by', 'reviewed_at', 'review_note'])]
class MosqueClaim extends Model
{
    /** @use HasFactory<MosqueClaimFactory> */
    use HasFactory;

    public const PENDING = 'pending';

    public const APPROVED = 'approved';

    public const REJECTED = 'rejected';

    protected function casts(): array
    {
        return ['reviewed_at' => 'datetime'];
    }

    public function mosque(): BelongsTo
    {
        return $this->belongsTo(Mosque::class);
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    public function reviewer(): BelongsTo
    {
        return $this->belongsTo(User::class, 'reviewed_by');
    }
}
