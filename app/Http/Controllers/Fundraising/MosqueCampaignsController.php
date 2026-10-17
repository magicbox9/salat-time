<?php

namespace App\Http\Controllers\Fundraising;

use App\Http\Controllers\Controller;
use App\Models\Campaign;
use App\Models\Mosque;
use App\Services\Fundraising\CampaignPresenter;
use App\Services\Fundraising\CampaignProgress;
use App\Support\MosquePresenter;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Cache;
use Inertia\Inertia;
use Inertia\Response;

/** A mosque's campaigns: its page (/mosques/{slug}/campaigns) and the JSON its widgets load. */
class MosqueCampaignsController extends Controller
{
    public function page(Request $request, Mosque $mosque): Response
    {
        $campaigns = $mosque->isVerified()
            ? Campaign::query()
                ->where('mosque_id', $mosque->id)
                ->whereIn('status', CampaignShowController::PUBLIC_STATUSES)
                ->orderByRaw("CASE WHEN status = 'active' THEN 0 ELSE 1 END")
                ->orderByRaw('starts_at DESC NULLS LAST')
                ->orderByDesc('id')
                ->limit(60)
                ->get()
            : collect();

        $cards = $campaigns->map(function (Campaign $campaign) use ($mosque) {
            $campaign->setRelation('mosque', $mosque);

            return CampaignPresenter::card($campaign);
        })->values();

        return Inertia::render('campaigns/mosque', [
            'mosque' => MosquePresenter::summary($mosque),
            'open' => $cards->filter(fn (array $c) => in_array($c['state'], ['active', 'upcoming'], true))->values()->all(),
            'ended' => $cards->reject(fn (array $c) => in_array($c['state'], ['active', 'upcoming'], true))->values()->all(),
            'canManage' => (bool) $request->user()?->can('manage', $mosque),
        ]);
    }

    /** Contract C2: the mosque's open campaigns with their progress (public, cached). */
    public function json(Mosque $mosque): JsonResponse
    {
        $campaigns = Cache::remember(CampaignProgress::mosqueKey($mosque->id), (int) config('fundraising.mosque_cache_seconds', 30), function () use ($mosque) {
            if (! $mosque->isVerified()) {
                return [];
            }

            return Campaign::query()
                ->where('mosque_id', $mosque->id)
                ->where('status', 'active')
                ->where(fn ($q) => $q->whereNull('ends_at')->orWhere('ends_at', '>', now()))
                ->where(fn ($q) => $q->whereNull('starts_at')->orWhere('starts_at', '<=', now()))
                ->orderByRaw('starts_at DESC NULLS LAST')
                ->orderByDesc('id')
                ->limit(6)
                ->get()
                ->map(function (Campaign $campaign) use ($mosque) {
                    $campaign->setRelation('mosque', $mosque);

                    return CampaignPresenter::card($campaign);
                })
                ->values()
                ->all();
        });

        return response()->json(['campaigns' => $campaigns])
            ->header('Cache-Control', 'public, max-age=30');
    }
}
