<?php

namespace App\Services\Fundraising;

use App\Models\Campaign;
use App\Models\Mosque;

/**
 * Why a mosque or a campaign cannot go to review yet. Each problem is a key
 * the pages translate ("fundraising.problem_{key}").
 *
 * Only a verified mosque with at least one verified payout method may submit
 * a campaign, and every way of giving the campaign allows must be verified.
 */
class CampaignEligibility
{
    public function __construct(private readonly PaymentMethods $methods) {}

    /** @return list<string> */
    public function mosqueProblems(Mosque $mosque): array
    {
        $problems = [];
        if (! $mosque->isVerified()) {
            $problems[] = 'mosque_unverified';
        }
        $allowable = $this->methods->allowable($mosque);
        if (! $allowable['paypal'] && ! $allowable['bank']) {
            $problems[] = 'no_verified_payout';
        }

        return $problems;
    }

    /** @return list<string> */
    public function submissionProblems(Campaign $campaign, Mosque $mosque): array
    {
        $problems = $this->mosqueProblems($mosque);
        $allowable = $this->methods->allowable($mosque);

        if (! $campaign->allow_paypal && ! $campaign->allow_bank) {
            $problems[] = 'no_method';
        }
        if (($campaign->allow_paypal && ! $allowable['paypal']) || ($campaign->allow_bank && ! $allowable['bank'])) {
            $problems[] = 'method_unverified';
        }
        $ends = ModelDate::of($campaign, 'ends_at');
        if ($ends && ! $ends->isFuture()) {
            $problems[] = 'ended';
        }

        return array_values(array_unique($problems));
    }
}
