<?php

namespace App\Services\Fundraising;

use App\Models\Campaign;
use Illuminate\Support\Facades\Cache;

/**
 * The live figures of a campaign (polled every ~10 s by its page), cached a
 * few seconds so a crowd of visitors costs one query. Every change of a
 * donation forgets the cache (DonationLedger::recount).
 */
class CampaignProgress
{
    /** @return array<string, mixed> */
    public static function for(Campaign $campaign): array
    {
        return Cache::remember(self::key($campaign->id), (int) config('fundraising.progress_cache_seconds', 5), function () use ($campaign) {
            $fresh = Campaign::query()->find($campaign->id) ?? $campaign;

            return [
                ...CampaignPresenter::totals($fresh),
                'status' => $fresh->status,
                'state' => CampaignPresenter::state($fresh),
                'days_left' => CampaignPresenter::daysLeft($fresh),
                'recent' => CampaignPresenter::wall($fresh),
                'updated_at' => now()->toIso8601String(),
            ];
        });
    }

    public static function forget(Campaign $campaign): void
    {
        Cache::forget(self::key($campaign->id));
        Cache::forget(self::mosqueKey($campaign->mosque_id));
    }

    public static function key(int $campaignId): string
    {
        return 'campaign-progress:'.$campaignId;
    }

    public static function mosqueKey(int $mosqueId): string
    {
        return 'mosque-campaigns:'.$mosqueId;
    }
}
