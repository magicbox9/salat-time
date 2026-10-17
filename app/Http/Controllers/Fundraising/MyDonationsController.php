<?php

namespace App\Http\Controllers\Fundraising;

use App\Http\Controllers\Controller;
use App\Models\Campaign;
use App\Models\Donation;
use App\Models\Mosque;
use App\Services\Fundraising\AbandonedCheckouts;
use App\Services\Fundraising\CampaignPresenter;
use App\Services\Fundraising\ModelDate;
use Illuminate\Http\Request;
use Inertia\Inertia;
use Inertia\Response;

/** /me/donations — the signed-in user's donations and where each one stands. */
class MyDonationsController extends Controller
{
    public function __invoke(Request $request): Response
    {
        $userId = (int) $request->user()?->getAuthIdentifier();
        // PayPal windows closed without paying are not donations.
        $page = AbandonedCheckouts::exclude(Donation::query()->where('user_id', $userId))
            ->latest()
            ->orderByDesc('id')
            ->paginate(20);

        // Two queries for the whole page (campaigns may since have been deleted).
        $donations = collect($page->items());
        $campaigns = Campaign::withTrashed()->whereIn('id', $donations->pluck('campaign_id')->unique())
            ->get(['id', 'slug', 'title', 'cover_path', 'deleted_at'])->keyBy('id');
        $mosques = Mosque::query()->whereIn('id', $donations->pluck('mosque_id')->unique())
            ->get(['id', 'slug', 'name', 'city'])->keyBy('id');

        $page->through(function (Donation $donation) use ($campaigns, $mosques): array {
            $campaign = $campaigns->get($donation->campaign_id);
            $mosque = $mosques->get($donation->mosque_id);

            return [
                'reference' => $donation->reference,
                'amount' => (int) $donation->amount,
                'currency' => $donation->currency,
                'method' => $donation->method,
                'status' => $donation->status,
                'anonymous' => (bool) $donation->anonymous,
                'created_at' => ModelDate::iso($donation, 'created_at'),
                'campaign' => $campaign ? [
                    'slug' => $campaign->slug,
                    'title' => $campaign->title,
                    'cover_url' => CampaignPresenter::coverUrl($campaign->cover_path),
                    'visible' => ! $campaign->trashed(),
                ] : null,
                'mosque' => $mosque ? ['slug' => $mosque->slug, 'name' => $mosque->name, 'city' => $mosque->city] : null,
                'receipt_url' => DonationReceiptController::link($donation->reference),
            ];
        });

        $totals = Donation::query()
            ->where('user_id', $userId)
            ->where('status', 'completed')
            ->selectRaw('COALESCE(SUM(amount), 0) AS total, COUNT(*) AS count')
            ->toBase()
            ->first();

        return Inertia::render('me/donations', [
            'donations' => $page,
            'totals' => [
                'amount' => (int) ($totals->total ?? 0),
                'count' => (int) ($totals->count ?? 0),
                'currency' => config('fundraising.currency'),
            ],
        ]);
    }
}
