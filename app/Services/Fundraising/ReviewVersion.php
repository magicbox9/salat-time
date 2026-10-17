<?php

namespace App\Services\Fundraising;

use App\Models\Campaign;
use App\Models\MosquePayoutMethod;
use App\Services\Payments\BankAccount;

/**
 * What an admin approves is exactly what they saw. The review pages carry a
 * short version of the reviewed content; approving a campaign or verifying
 * an account is refused when the content changed since (a manager edited the
 * story, or swapped the IBAN, while the admin was reading the old one).
 *
 * A keyed hash (the app key): it reveals nothing about the IBAN it covers.
 */
final class ReviewVersion
{
    public static function campaign(Campaign $campaign): string
    {
        return self::hash('campaign', [
            $campaign->id,
            $campaign->kind,
            $campaign->title,
            $campaign->summary,
            $campaign->story,
            $campaign->cover_path,
            (int) $campaign->goal_amount,
            ModelDate::iso($campaign, 'starts_at'),
            ModelDate::iso($campaign, 'ends_at'),
            (bool) $campaign->allow_paypal,
            (bool) $campaign->allow_bank,
            (bool) $campaign->show_donor_names,
        ]);
    }

    public static function payout(MosquePayoutMethod $payout): string
    {
        return self::hash('payout', [
            $payout->id,
            $payout->mosque_id,
            $payout->type,
            $payout->paypal_email,
            $payout->paypal_merchant_id,
            $payout->account_holder,
            $payout->iban ? BankAccount::normalizeIban($payout->iban) : null,
            $payout->bic,
            $payout->bank_name,
        ]);
    }

    /** True when the version sent back by the admin's page still matches. */
    public static function matches(string $current, mixed $seen): bool
    {
        return is_string($seen) && hash_equals($current, $seen);
    }

    /** @param  list<mixed>  $parts */
    private static function hash(string $kind, array $parts): string
    {
        return substr(hash_hmac('sha256', $kind.'|'.serialize($parts), (string) config('app.key')), 0, 32);
    }
}
