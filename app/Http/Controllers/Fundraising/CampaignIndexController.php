<?php

namespace App\Http\Controllers\Fundraising;

use App\Http\Controllers\Controller;
use App\Models\Campaign;
use App\Services\Fundraising\CampaignPresenter;
use App\Support\ChosenMosque;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Http\Request;
use Inertia\Inertia;
use Inertia\Response;

/**
 * /campaigns — campaigns of verified mosques, open ones first. Filters: kind,
 * open or ended, and "near me" (the visitor's own mosque, or a position the
 * browser shared).
 */
class CampaignIndexController extends Controller
{
    private const NEAR_RADIUS_KM = 150;

    public function __invoke(Request $request): Response
    {
        $kind = $this->choice($request, 'kind', Campaign::KINDS);
        $tab = $this->choice($request, 'tab', ['open', 'ended']) ?? 'open';
        $chosen = ChosenMosque::for($request);
        [$near, $lat, $lng] = $this->near($request, $chosen?->latitude, $chosen?->longitude);

        $query = Campaign::query()
            ->join('mosques', 'mosques.id', '=', 'campaigns.mosque_id')
            ->whereNotNull('mosques.verified_at')
            ->select('campaigns.*')
            ->with('mosque:id,slug,name,city,country_code,verified_at,logo_path');

        $this->scopeTab($query, $tab);
        $query->when($kind, fn (Builder $q) => $q->where('campaigns.kind', $kind));

        if ($near !== null) {
            $point = 'll_to_earth(?, ?)';
            $here = 'll_to_earth(mosques.latitude::float8, mosques.longitude::float8)';
            $query->selectRaw("earth_distance($point, $here) AS distance_m", [$lat, $lng])
                ->whereRaw("earth_box($point, ?) @> $here", [$lat, $lng, self::NEAR_RADIUS_KM * 1000])
                ->orderBy('distance_m');
        }

        $campaigns = $query
            ->orderByRaw('campaigns.starts_at DESC NULLS LAST')
            ->orderByDesc('campaigns.id')
            ->paginate(12)
            ->withQueryString()
            ->through(fn (Campaign $campaign) => CampaignPresenter::card($campaign));

        return Inertia::render('campaigns/index', [
            'campaigns' => $campaigns,
            'filters' => ['kind' => $kind, 'tab' => $tab, 'near' => $near],
            'kinds' => Campaign::KINDS,
            'chosenMosque' => $chosen ? ['slug' => $chosen->slug, 'name' => $chosen->name] : null,
        ]);
    }

    /** @param  Builder<Campaign>  $query */
    private function scopeTab(Builder $query, string $tab): void
    {
        if ($tab === 'ended') {
            $query->where(fn (Builder $q) => $q->whereIn('campaigns.status', ['completed', 'closed'])
                ->orWhere(fn (Builder $q) => $q->where('campaigns.status', 'active')->where('campaigns.ends_at', '<=', now())));

            return;
        }

        $query->where('campaigns.status', 'active')
            ->where(fn (Builder $q) => $q->whereNull('campaigns.ends_at')->orWhere('campaigns.ends_at', '>', now()))
            ->where(fn (Builder $q) => $q->whereNull('campaigns.starts_at')->orWhere('campaigns.starts_at', '<=', now()));
    }

    /**
     * "mine" (the visitor's own mosque) or "here" (lat/lng from the browser).
     *
     * @return array{0: string|null, 1: float|null, 2: float|null}
     */
    private function near(Request $request, ?float $mineLat, ?float $mineLng): array
    {
        $near = $request->query('near');
        if ($near === 'mine' && $mineLat !== null && $mineLng !== null) {
            return ['mine', $mineLat, $mineLng];
        }

        $lat = filter_var($request->query('lat'), FILTER_VALIDATE_FLOAT);
        $lng = filter_var($request->query('lng'), FILTER_VALIDATE_FLOAT);
        if ($near === 'here' && $lat !== false && $lng !== false && abs($lat) <= 90 && abs($lng) <= 180) {
            // About a kilometre: plenty for a 150 km search, and no more than that is kept in logs.
            return ['here', round($lat, 2), round($lng, 2)];
        }

        return [null, null, null];
    }

    /** @param  list<string>  $allowed */
    private function choice(Request $request, string $key, array $allowed): ?string
    {
        $value = $request->query($key);

        return is_string($value) && in_array($value, $allowed, true) ? $value : null;
    }
}
