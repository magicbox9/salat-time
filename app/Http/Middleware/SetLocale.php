<?php

namespace App\Http\Middleware;

use App\Support\Ui;
use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

/** Picks the interface language: saved choice, then the account's, then the browser's. */
class SetLocale
{
    public function handle(Request $request, Closure $next): Response
    {
        $supported = array_keys(Ui::LOCALES);
        $locale = $request->session()->get('locale')
            ?? $request->user()?->locale
            ?? $request->getPreferredLanguage($supported)
            ?? 'en';
        app()->setLocale(in_array($locale, $supported, true) ? $locale : 'en');

        return $next($request);
    }
}
