<?php

namespace App\Console\Commands;

use App\Models\Campaign;
use App\Models\Donation;
use App\Services\Fundraising\DonationLedger;
use Illuminate\Console\Attributes\Description;
use Illuminate\Console\Attributes\Signature;
use Illuminate\Console\Command;

/**
 * Daily housekeeping (scheduled in routes/console.php):
 *  - bank-transfer pledges never confirmed by the mosque expire, so fake or
 *    forgotten pledges stop inflating a campaign's "pledged" amount;
 *  - campaigns past their end date are marked completed.
 */
#[Signature('fundraising:tidy {--days= : Days after which an unconfirmed bank pledge expires (default from config)}')]
#[Description('Expire stale bank pledges and close campaigns that have ended')]
class TidyFundraising extends Command
{
    public function handle(DonationLedger $ledger): int
    {
        $days = (int) ($this->option('days') ?: config('fundraising.pledge_expiry_days', 30));
        $expired = 0;

        Donation::query()
            ->where('method', 'bank')
            ->where('status', 'pending')
            ->where('created_at', '<', now()->subDays($days))
            ->orderBy('id')
            ->each(function (Donation $donation) use ($ledger, &$expired) {
                if ($ledger->cancel($donation)) {
                    $expired++;
                }
            });

        $closed = Campaign::query()
            ->where('status', 'active')
            ->whereNotNull('ends_at')
            ->where('ends_at', '<', now())
            ->update(['status' => 'completed', 'updated_at' => now()]);

        $this->info("Expired bank pledges: $expired · campaigns closed: $closed");

        return self::SUCCESS;
    }
}
