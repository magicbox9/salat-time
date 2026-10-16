<?php

namespace App\Support;

use App\Http\Controllers\Discover\Support\MyMosque;
use App\Models\Mosque;
use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Cookie;
use Illuminate\Validation\ValidationException;
use Symfony\Component\HttpFoundation\Cookie as SymfonyCookie;

/**
 * The visitor's own mosque, the centre of the app ("/" opens on its prayer
 * times, "/display" shows it full screen).
 *
 * - Signed in: the primary saved mosque (favorite_mosques.is_primary).
 * - Guest: the encrypted cookie "my_mosque" holding the mosque's slug.
 *
 * When a signed-in user has no own mosque yet but this browser holds a guest
 * choice, that choice is adopted (made primary) and the cookie is dropped:
 * at sign-in (AdoptGuestMosque listens to Login) and, as a fallback, on the
 * first resolution after it.
 */
class ChosenMosque
{
    public const COOKIE = 'my_mosque';

    /** One year. */
    public const MINUTES = 525_600;

    private const SLUG = '/^[a-z0-9-]{1,255}$/';

    private const MEMO = 'chosen_mosque';

    public static function for(Request $request): ?Mosque
    {
        if ($request->attributes->has(self::MEMO)) {
            return $request->attributes->get(self::MEMO);
        }

        $user = $request->user();
        $mosque = $user instanceof User
            ? (MyMosque::of($user) ?? self::adopt($request, $user))
            : self::fromCookie($request);
        $request->attributes->set(self::MEMO, $mosque);

        return $mosque;
    }

    /** "user" (primary saved mosque), "cookie" (guest) or null. */
    public static function source(Request $request): ?string
    {
        if (! self::for($request)) {
            return null;
        }

        return $request->user() ? 'user' : 'cookie';
    }

    /**
     * Makes this browser's guest choice the user's own mosque when they have
     * none yet. Returns the adopted mosque.
     */
    public static function adopt(Request $request, User $user): ?Mosque
    {
        $mosque = self::fromCookie($request);
        if (! $mosque) {
            return null;
        }

        try {
            $adopted = MyMosque::choose($user, $mosque, onlyIfNone: true);
        } catch (ValidationException) {
            // A full list of saved mosques: keep the guest choice for later.
            return null;
        }
        // The choice now lives on the account; the cookie is only for guests.
        Cookie::queue(self::forget());
        $request->attributes->remove(self::MEMO);

        return $adopted ? $mosque : MyMosque::of($user);
    }

    /** The mosque named by the guest cookie (a stale or forged value is dropped). */
    public static function fromCookie(Request $request): ?Mosque
    {
        $slug = $request->cookie(self::COOKIE);
        if (! is_string($slug) || $slug === '') {
            return null;
        }

        $mosque = preg_match(self::SLUG, $slug) ? Mosque::query()->where('slug', $slug)->first() : null;
        if (! $mosque) {
            Cookie::queue(self::forget());
        }

        return $mosque;
    }

    public static function cookie(Mosque $mosque): SymfonyCookie
    {
        return Cookie::make(self::COOKIE, $mosque->slug, self::MINUTES, '/', null, null, true, false, 'lax');
    }

    public static function forget(): SymfonyCookie
    {
        return Cookie::forget(self::COOKIE);
    }
}
