<?php

namespace App\Http\Controllers\Auth;

use App\Http\Controllers\Controller;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;

/**
 * GET /sign-in?return=/mosques/x — "sign in to do this": remembers the page
 * the guest was on, so signing in (or signing up) brings them back to it.
 * Only a path on this site is accepted, never another host.
 */
class SignInReturnController extends Controller
{
    public function __invoke(Request $request): RedirectResponse
    {
        $return = self::safePath($request->query('return'));

        if ($request->user()) {
            return redirect()->to($return ?? route('home'));
        }
        if ($return !== null) {
            redirect()->setIntendedUrl(url($return));
        }

        return redirect()->route('login');
    }

    /** "/mosques/x?tab=1" is kept; "//host", "https://host", "/\host" and control characters are not. */
    public static function safePath(mixed $value): ?string
    {
        if (! is_string($value) || $value === '' || strlen($value) > 2000) {
            return null;
        }
        if ($value[0] !== '/' || str_starts_with($value, '//') || str_contains($value, '\\') || preg_match('/[\x00-\x1F\x7F]/', $value)) {
            return null;
        }
        $parts = parse_url($value);

        return $parts !== false && ! isset($parts['scheme']) && ! isset($parts['host']) ? $value : null;
    }
}
