<?php

namespace App\Http\Controllers\Dev;

use App\Http\Controllers\Controller;
use App\Models\User;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;

/** Development only: sign in as one of the seeded test accounts with one click. */
class DevLoginController extends Controller
{
    public function __invoke(Request $request, string $account): RedirectResponse
    {
        abort_unless(config('devlogin.enabled') && app()->isLocal(), 404);

        $email = config("devlogin.accounts.$account");
        $user = $email ? User::query()->where('email', $email)->first() : null;
        abort_unless($user, 404, 'Run: php artisan db:seed --class=DevSeeder');

        Auth::login($user, remember: true);
        $request->session()->regenerate();

        return redirect()->intended(route('dashboard'));
    }
}
