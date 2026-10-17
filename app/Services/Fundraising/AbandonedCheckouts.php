<?php

namespace App\Services\Fundraising;

use App\Models\Donation;
use Illuminate\Database\Eloquent\Builder;

/**
 * A PayPal window closed (or refused) before any payment is not a donation:
 * the lists of the mosque and of the donor leave such attempts out, and they
 * never stop a campaign from being deleted.
 */
final class AbandonedCheckouts
{
    /**
     * @param  Builder<Donation>  $query
     * @return Builder<Donation>
     */
    public static function exclude(Builder $query): Builder
    {
        return $query->whereNot(fn (Builder $q) => $q
            ->where('method', 'paypal')
            ->whereIn('status', ['pending', 'cancelled', 'failed'])
            ->whereNull('paypal_capture_id'));
    }
}
