<?php

namespace App\Services\Fundraising;

use App\Models\Campaign;
use App\Models\Donation;
use Illuminate\Support\Facades\DB;

/**
 * Every change of a donation's status goes through here: the campaign row is
 * locked, then the donation, the status is re-read under the lock (so a
 * repeated capture, webhook or click changes nothing twice), and the
 * campaign's totals are recounted from the donations themselves.
 *
 *   raised  = completed donations
 *   pledged = bank transfers announced, not yet confirmed by the mosque
 *   donors  = completed donations
 */
class DonationLedger
{
    public function __construct(private readonly FundraisingMail $mail) {}

    /**
     * Marks the donation completed (the money is with the mosque) and thanks
     * the donor. Returns false when it was already completed or refunded.
     *
     * @param  array<string, mixed>  $attributes  Extra fields (capture id, confirmed_by…).
     */
    public function complete(Donation $donation, array $attributes = []): bool
    {
        $changed = $this->transition($donation, ['pending', 'cancelled', 'failed'], 'completed', $attributes);
        if ($changed) {
            $this->mail->thank($donation);
        }

        return $changed;
    }

    /** A pending donation that will not come (cancelled by the mosque or the donor, or refused). */
    public function cancel(Donation $donation, string $status = 'cancelled'): bool
    {
        return $this->transition($donation, ['pending'], $status === 'failed' ? 'failed' : 'cancelled');
    }

    /**
     * Money given back or taken back after it was received (refund, reversal, denial).
     *
     * @param  array<string, mixed>  $attributes
     */
    public function reverse(Donation $donation, string $status = 'refunded', array $attributes = []): bool
    {
        return $this->transition($donation, ['completed', 'pending'], $status === 'failed' ? 'failed' : 'refunded', $attributes);
    }

    /** Recounts a campaign's totals from its donations (call inside a transaction holding its lock). */
    public function recount(Campaign $campaign): void
    {
        $totals = DB::table('donations')
            ->where('campaign_id', $campaign->id)
            ->selectRaw("COALESCE(SUM(amount) FILTER (WHERE status = 'completed'), 0) AS raised")
            ->selectRaw("COALESCE(SUM(amount) FILTER (WHERE status = 'pending' AND method = 'bank'), 0) AS pledged")
            ->selectRaw("COUNT(*) FILTER (WHERE status = 'completed') AS donors")
            ->first();

        $campaign->forceFill([
            'raised_amount' => (int) ($totals->raised ?? 0),
            'pledged_amount' => (int) ($totals->pledged ?? 0),
            'donors_count' => (int) ($totals->donors ?? 0),
        ])->save();

        CampaignProgress::forget($campaign);
    }

    /** Recounts outside any other transaction (e.g. after creating a bank pledge). */
    public function refresh(int $campaignId): void
    {
        DB::transaction(function () use ($campaignId) {
            $campaign = Campaign::withTrashed()->lockForUpdate()->find($campaignId);
            if ($campaign) {
                $this->recount($campaign);
            }
        });
    }

    /**
     * @param  list<string>  $from
     * @param  array<string, mixed>  $attributes
     */
    private function transition(Donation $donation, array $from, string $to, array $attributes = []): bool
    {
        $changed = DB::transaction(function () use ($donation, $from, $to, $attributes): bool {
            // Same order everywhere (campaign, then donation): no deadlocks.
            $campaign = Campaign::withTrashed()->lockForUpdate()->find($donation->campaign_id);
            $locked = Donation::query()->lockForUpdate()->find($donation->id);
            if (! $campaign || ! $locked || ! in_array($locked->status, $from, true)) {
                if ($locked) {
                    $donation->setRawAttributes($locked->getAttributes(), true);
                }

                return false;
            }

            $locked->forceFill([...$attributes, 'status' => $to])->save();
            $this->recount($campaign);
            $donation->setRawAttributes($locked->getAttributes(), true);

            return true;
        });

        return $changed;
    }
}
