<?php

namespace App\Http\Controllers\Fundraising;

use App\Http\Controllers\Controller;
use App\Models\Campaign;
use App\Models\Mosque;
use App\Services\Fundraising\CampaignProgress;
use Illuminate\Http\JsonResponse;

/**
 * GET /campaigns/{slug}/progress.json — live figures, polled by the campaign
 * page. Public exactly when the page is: a published campaign of a verified
 * mosque (the recent donations it lists are no one else's business).
 */
class CampaignProgressController extends Controller
{
    public function __invoke(Campaign $campaign): JsonResponse
    {
        abort_unless(
            in_array($campaign->status, CampaignShowController::PUBLIC_STATUSES, true)
                && Mosque::query()->whereKey($campaign->mosque_id)->whereNotNull('verified_at')->exists(),
            404,
        );

        return response()
            ->json(CampaignProgress::for($campaign))
            ->header('Cache-Control', 'public, max-age='.(int) config('fundraising.progress_cache_seconds', 5));
    }
}
