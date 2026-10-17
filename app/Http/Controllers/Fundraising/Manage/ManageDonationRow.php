<?php

namespace App\Http\Controllers\Fundraising\Manage;

use App\Models\Campaign;
use App\Models\Donation;
use App\Services\Fundraising\ModelDate;

/**
 * One donation as the mosque's managers see it: the donor's email is there
 * (the mosque writes tax receipts), whatever the public may see.
 */
final class ManageDonationRow
{
    /** @return array<string, mixed> */
    public static function from(Donation $donation): array
    {
        $campaign = $donation->relationLoaded('campaign') ? $donation->getRelation('campaign') : null;

        return [
            'id' => $donation->id,
            'reference' => $donation->reference,
            'donor_name' => $donation->donor_name,
            'donor_email' => $donation->donor_email,
            'anonymous' => (bool) $donation->anonymous,
            'message' => $donation->message,
            'amount' => (int) $donation->amount,
            'currency' => $donation->currency,
            'method' => $donation->method,
            'status' => $donation->status,
            'created_at' => ModelDate::iso($donation, 'created_at'),
            'confirmed_at' => ModelDate::iso($donation, 'confirmed_at'),
            'campaign' => $campaign instanceof Campaign ? ['slug' => $campaign->slug, 'title' => $campaign->title] : null,
            'can_confirm' => $donation->method === 'bank' && $donation->status === 'pending',
        ];
    }
}
