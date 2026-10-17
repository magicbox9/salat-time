<?php

namespace App\Http\Controllers\Fundraising;

use App\Http\Controllers\Controller;
use App\Models\Campaign;
use App\Models\User;
use App\Services\Fundraising\CampaignPresenter;
use App\Services\Fundraising\CampaignProgress;
use App\Services\Fundraising\PaymentMethods;
use App\Services\Payments\PayPalClient;
use Illuminate\Http\Request;
use Inertia\Inertia;
use Inertia\Response;

/**
 * /campaigns/{slug} — the campaign's page: story, live progress, updates,
 * recent donations and the donate panel. Drafts, campaigns under review and
 * rejected ones are visible to the mosque's managers and admins only.
 * Completed and closed campaigns stay visible, without the donate panel.
 */
class CampaignShowController extends Controller
{
    public const PUBLIC_STATUSES = ['active', 'completed', 'closed'];

    public function __invoke(Request $request, Campaign $campaign, PaymentMethods $methods, PayPalClient $paypal): Response
    {
        $campaign->load('mosque.payoutMethods');
        $mosque = CampaignPresenter::mosqueOf($campaign);
        /** @var User|null $user */
        $user = $request->user();
        $canManage = $user && $mosque && $user->can('manage', $mosque);

        abort_unless($mosque && ($canManage || (in_array($campaign->status, self::PUBLIC_STATUSES, true) && $mosque->isVerified())), 404);

        $available = $methods->available($campaign);
        $payouts = $methods->verifiedPayouts($mosque);
        $paypalProps = $available['paypal'] && $payouts['paypal']
            ? [
                'client_id' => $paypal->clientId(),
                'merchant' => PaymentMethods::sdkMerchant($payouts['paypal']),
                'sdk_url' => config('fundraising.paypal.sdk_url'),
                'sandbox' => $paypal->mode() === 'sandbox',
            ]
            : null;

        return Inertia::render('campaigns/show', [
            'campaign' => CampaignPresenter::detail($campaign),
            'progress' => CampaignProgress::for($campaign),
            'updates' => CampaignPresenter::updates($campaign),
            'methods' => $available,
            'paypal' => $paypalProps,
            'presets' => array_values(array_map('intval', (array) config('fundraising.presets'))),
            'limits' => ['min' => (int) config('fundraising.min_amount'), 'max' => (int) config('fundraising.max_amount')],
            'donor' => $user ? ['name' => $user->name, 'email' => $user->email] : null,
            'canManage' => (bool) $canManage,
            'shareUrl' => url('/campaigns/'.$campaign->slug),
        ]);
    }
}
