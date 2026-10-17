<?php

namespace App\Services\Fundraising;

use App\Models\Campaign;
use App\Models\CampaignUpdate;
use App\Models\Donation;
use App\Models\Mosque;
use App\Support\Markdown;
use Carbon\CarbonInterface;

/**
 * The campaign fields pages and JSON endpoints rely on. Donor emails never
 * leave the server here; a donor's name is shown only when they did not ask
 * to stay anonymous and the campaign shows names.
 */
class CampaignPresenter
{
    /** "active" | "upcoming" | "ended" | the stored status (draft, pending, completed, closed, rejected). */
    public static function state(Campaign $campaign): string
    {
        if ($campaign->status !== 'active') {
            return (string) $campaign->status;
        }
        if (ModelDate::of($campaign, 'starts_at')?->isFuture()) {
            return 'upcoming';
        }
        $ends = ModelDate::of($campaign, 'ends_at');

        return $ends && ! $ends->isFuture() ? 'ended' : 'active';
    }

    public static function daysLeft(Campaign $campaign): ?int
    {
        $ends = ModelDate::of($campaign, 'ends_at');
        if (! $ends || self::state($campaign) !== 'active') {
            return null;
        }

        return max(0, (int) ceil(now()->diffInSeconds($ends) / 86400));
    }

    public static function percent(Campaign $campaign): float
    {
        return $campaign->goal_amount > 0 ? round($campaign->raised_amount * 100 / $campaign->goal_amount, 1) : 0.0;
    }

    public static function coverUrl(?string $path): ?string
    {
        return $path ? asset('storage/'.$path) : null;
    }

    /** The campaign's mosque when the relation is loaded (or can be). */
    public static function mosqueOf(Campaign $campaign): ?Mosque
    {
        $mosque = $campaign->getRelationValue('mosque');

        return $mosque instanceof Mosque ? $mosque : null;
    }

    /** @return array<string, mixed> A card in lists (the mosque relation should be loaded). */
    public static function card(Campaign $campaign): array
    {
        $mosque = self::mosqueOf($campaign);

        return [
            'id' => $campaign->id,
            'slug' => $campaign->slug,
            'kind' => $campaign->kind,
            'title' => $campaign->title,
            'summary' => $campaign->summary,
            'cover_url' => self::coverUrl($campaign->cover_path),
            'status' => $campaign->status,
            'state' => self::state($campaign),
            'starts_at' => ModelDate::iso($campaign, 'starts_at'),
            'ends_at' => ModelDate::iso($campaign, 'ends_at'),
            'days_left' => self::daysLeft($campaign),
            ...self::totals($campaign),
            'mosque' => $mosque ? self::mosque($mosque) : null,
            'distance_m' => $campaign->getAttribute('distance_m') !== null ? (int) round((float) $campaign->getAttribute('distance_m')) : null,
        ];
    }

    /** @return array<string, mixed> */
    public static function totals(Campaign $campaign): array
    {
        return [
            'currency' => $campaign->currency,
            'goal' => (int) $campaign->goal_amount,
            'raised' => (int) $campaign->raised_amount,
            'pledged' => (int) $campaign->pledged_amount,
            'donors_count' => (int) $campaign->donors_count,
            'percent' => self::percent($campaign),
        ];
    }

    /** @return array<string, mixed> The full public page of a campaign. */
    public static function detail(Campaign $campaign): array
    {
        return [
            ...self::card($campaign),
            'story_html' => Markdown::toHtml($campaign->story),
            'show_donor_names' => (bool) $campaign->show_donor_names,
            'created_at' => ModelDate::iso($campaign, 'created_at'),
        ];
    }

    /** @return array<string, mixed> */
    public static function mosque(Mosque $mosque): array
    {
        return [
            'id' => $mosque->id,
            'slug' => $mosque->slug,
            'name' => $mosque->name,
            'city' => $mosque->city,
            'country_code' => $mosque->country_code,
            'verified' => $mosque->isVerified(),
            'logo_url' => $mosque->logo_path ? asset('storage/'.$mosque->logo_path) : null,
        ];
    }

    /** @return array<string, mixed> One line of the public donations wall. */
    public static function wallEntry(Donation $donation, bool $showNames): array
    {
        return [
            'id' => $donation->id,
            'name' => $showNames && ! $donation->anonymous && $donation->donor_name ? $donation->donor_name : null,
            'amount' => (int) $donation->amount,
            'currency' => $donation->currency,
            'message' => $donation->message ?: null,
            'at' => ModelDate::iso($donation, 'confirmed_at') ?? ModelDate::iso($donation, 'created_at'),
        ];
    }

    /** @return array<int, array<string, mixed>> The latest completed donations. */
    public static function wall(Campaign $campaign, ?int $limit = null): array
    {
        return Donation::query()
            ->where('campaign_id', $campaign->id)
            ->where('status', 'completed')
            // When the gift arrived (later bookkeeping, e.g. a webhook note, never reorders it).
            ->orderByRaw('COALESCE(confirmed_at, created_at) DESC')
            ->orderByDesc('id')
            ->limit($limit ?? (int) config('fundraising.wall_size', 12))
            ->get(['id', 'donor_name', 'anonymous', 'message', 'amount', 'currency', 'confirmed_at', 'created_at'])
            ->map(fn (Donation $d) => self::wallEntry($d, (bool) $campaign->show_donor_names))
            ->values()
            ->all();
    }

    /** @return array<string, mixed> One piece of news on a campaign. */
    public static function update(CampaignUpdate $update): array
    {
        return [
            'id' => $update->id,
            'title' => $update->title,
            'body_html' => Markdown::toHtml($update->body),
            'created_at' => ModelDate::iso($update, 'created_at'),
        ];
    }

    /**
     * The campaign's news, newest first.
     *
     * @return array<int, array<string, mixed>>
     */
    public static function updates(Campaign $campaign, int $limit = 30): array
    {
        return CampaignUpdate::query()
            ->where('campaign_id', $campaign->id)
            ->latest()
            ->orderByDesc('id')
            ->limit($limit)
            ->get()
            ->map(fn (CampaignUpdate $update) => self::update($update))
            ->values()
            ->all();
    }

    public static function iso(mixed $date): ?string
    {
        return $date instanceof CarbonInterface ? $date->toIso8601String() : null;
    }
}
