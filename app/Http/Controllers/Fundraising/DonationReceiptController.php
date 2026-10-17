<?php

namespace App\Http\Controllers\Fundraising;

use App\Http\Controllers\Controller;
use App\Models\Campaign;
use App\Models\Donation;
use App\Models\Mosque;
use App\Services\Fundraising\CampaignPresenter;
use App\Services\Fundraising\PaymentMethods;
use App\Services\Fundraising\PayoutPresenter;
use Illuminate\Support\Facades\URL;
use Inertia\Inertia;
use Inertia\Response;

/**
 * The donor's own page for one donation (a signed link: after giving, in the
 * emails, from "My donations"): thanks, status, and for a bank transfer the
 * mosque's account, the exact amount and the reference to use.
 */
class DonationReceiptController extends Controller
{
    /**
     * The donor's signed link. The signature covers the path and query only
     * (signed:relative), so it stays valid behind a proxy or another host name.
     */
    public static function link(string $reference, bool $absolute = false): string
    {
        $path = URL::signedRoute('donations.show', ['reference' => $reference], absolute: false);

        return $absolute ? url($path) : $path;
    }

    public function __invoke(string $reference, PaymentMethods $methods): Response
    {
        $donation = Donation::query()->where('reference', $reference)->firstOrFail();
        $mosque = Mosque::query()->with('payoutMethods')->find($donation->mosque_id);
        /** @var Campaign $campaign */
        $campaign = Campaign::withTrashed()->with('mosque')->findOrFail($donation->campaign_id);

        $bank = null;
        if ($donation->method === 'bank' && $donation->status === 'pending' && $mosque) {
            $payout = $methods->verifiedPayouts($mosque)['bank'];
            $bank = $payout ? PayoutPresenter::transfer($payout) : null;
        }

        return Inertia::render('campaigns/donation', [
            'donation' => [
                'reference' => $donation->reference,
                'amount' => (int) $donation->amount,
                'currency' => $donation->currency,
                'method' => $donation->method,
                'status' => $donation->status,
                'anonymous' => (bool) $donation->anonymous,
                'donor_name' => $donation->donor_name,
                'created_at' => CampaignPresenter::iso($donation->created_at),
            ],
            'campaign' => CampaignPresenter::card($campaign),
            'bank' => $bank,
        ]);
    }
}
