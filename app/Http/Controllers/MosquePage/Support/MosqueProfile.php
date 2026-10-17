<?php

namespace App\Http\Controllers\MosquePage\Support;

use App\Models\Mosque;
use App\Models\MosqueClaim;
use App\Models\User;
use App\Support\MosquePresenter;
use Illuminate\Support\Facades\DB;

/** The public profile of a mosque page and what the current visitor may do there. */
class MosqueProfile
{
    /** @return array<string, mixed> */
    public static function details(Mosque $mosque): array
    {
        return [
            ...MosquePresenter::summary($mosque),
            'association' => $mosque->association,
            'description' => $mosque->description,
            'website' => self::safeWebsite($mosque->website),
            'phone' => $mosque->phone,
            'email' => $mosque->email,
            'cover_url' => PostPresenter::url($mosque->cover_path),
            'tagline' => $mosque->tagline,
            'accent' => AccentColor::present($mosque->accent_color),
            'social_links' => SocialLinks::present($mosque->social_links),
            'jumua' => array_values(array_filter([$mosque->jumua, $mosque->jumua2, $mosque->jumua3])),
            'jumua_as_dhuhr' => (bool) $mosque->jumua_as_dhuhr,
        ];
    }

    /**
     * @param  bool  $guestChoice  a guest chose this mosque as their own (cookie)
     * @return array<string, bool>
     */
    public static function viewer(?User $user, Mosque $mosque, bool $canManage, bool $guestChoice = false): array
    {
        $favorite = $user ? DB::table('favorite_mosques')
            ->where('user_id', $user->id)
            ->where('mosque_id', $mosque->id)
            ->first(['is_primary']) : null;

        return [
            'signed_in' => $user !== null,
            'verified' => $user?->hasVerifiedEmail() ?? false,
            'favorite' => $favorite !== null,
            'primary' => $user ? (bool) ($favorite->is_primary ?? false) : $guestChoice,
            'can_manage' => $canManage,
            'pending_claim' => $user !== null && ! $canManage && $mosque->claims()
                ->where('user_id', $user->id)
                ->where('status', MosqueClaim::PENDING)
                ->exists(),
        ];
    }

    /** Imported websites are shown as links only when they are plain http(s) URLs. */
    public static function safeWebsite(?string $url): ?string
    {
        if (! $url) {
            return null;
        }
        $url = trim($url);
        if (! preg_match('#^https?://#i', $url)) {
            $url = 'https://'.$url;
        }

        $host = (string) parse_url($url, PHP_URL_HOST);

        return filter_var($url, FILTER_VALIDATE_URL) && str_contains($host, '.') ? $url : null;
    }
}
