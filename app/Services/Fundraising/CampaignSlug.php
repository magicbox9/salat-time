<?php

namespace App\Services\Fundraising;

use App\Models\Campaign;
use Illuminate\Support\Str;

/** A unique, readable address for a new campaign ("toiture-de-la-mosquee-el-houda"). */
final class CampaignSlug
{
    public static function for(string $title, string $mosqueName): string
    {
        $base = Str::of(Str::slug($title))->limit(80, '')->trim('-')->toString();
        if ($base === '') {
            $base = Str::of(Str::slug($mosqueName))->limit(80, '')->trim('-')->toString();
        }
        if ($base === '') {
            $base = 'campaign';
        }
        // Words used by the management routes (campaigns/create).
        if (in_array($base, ['create', 'edit'], true)) {
            $base .= '-campaign';
        }

        $slug = $base;
        for ($n = 2; Campaign::withTrashed()->where('slug', $slug)->exists(); $n++) {
            $slug = $n < 20 ? $base.'-'.$n : $base.'-'.Str::lower(Str::random(6));
        }

        return $slug;
    }
}
