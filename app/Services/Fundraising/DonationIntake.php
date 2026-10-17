<?php

namespace App\Services\Fundraising;

use App\Models\Campaign;
use App\Models\Donation;
use App\Models\User;
use Illuminate\Database\UniqueConstraintViolationException;
use Illuminate\Support\Str;

/**
 * Records a donor's intention as a pending donation. The amount, method and
 * campaign are validated before; the reference is unique; a bank transfer
 * shows at once as "pledged" on the campaign.
 */
class DonationIntake
{
    public function __construct(private readonly DonationLedger $ledger) {}

    /**
     * @param  array{amount: int, donor_name: string, donor_email: string, anonymous?: bool, message?: string|null}  $data
     */
    public function create(Campaign $campaign, string $method, array $data, ?User $user): Donation
    {
        $message = isset($data['message']) ? Str::of($data['message'])->trim()->limit(500, '')->toString() : '';

        for ($attempt = 1; ; $attempt++) {
            $donation = new Donation([
                'campaign_id' => $campaign->id,
                'mosque_id' => $campaign->mosque_id,
                'user_id' => $user?->id,
                'donor_name' => Str::squish($data['donor_name']),
                'donor_email' => Str::lower(trim($data['donor_email'])),
                'anonymous' => (bool) ($data['anonymous'] ?? false),
                'message' => $message !== '' ? $message : null,
                'amount' => (int) $data['amount'],
                'currency' => $campaign->currency,
                'method' => $method,
                'reference' => DonationReference::generate(),
            ]);
            $donation->forceFill(['status' => 'pending', 'locale' => app()->getLocale()]);

            try {
                $donation->save();
                break;
            } catch (UniqueConstraintViolationException $e) {
                if ($attempt >= 3) {
                    throw $e;
                }
            }
        }

        if ($method === 'bank') {
            $this->ledger->refresh($campaign->id);
        }

        return $donation;
    }
}
