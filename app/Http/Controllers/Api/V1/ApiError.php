<?php

namespace App\Http\Controllers\Api\V1;

use App\Support\Ui;
use Closure;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Routing\Controllers\Middleware;
use Symfony\Component\HttpFoundation\Response;

/**
 * API v1 conventions. Success: {"data": …, "meta"?: …}. Errors: {"message": …,
 * "code"?: …} — validation errors (422) add Laravel's {"errors": {field: [..]}}.
 */
final class ApiError
{
    public static function response(string $code, string $message, int $status): JsonResponse
    {
        return response()->json(['message' => $message, 'code' => $code], $status);
    }

    /** The device's IANA time zone: X-Timezone header or ?tz=. Used only without an own mosque. */
    public static function deviceTimezone(Request $request): ?string
    {
        $value = $request->header('X-Timezone') ?? $request->input('tz');

        return is_string($value) && strlen($value) <= 64 ? $value : null;
    }

    /**
     * Controller middleware: messages (validation included) in the person's
     * language — the one saved on their account, else Accept-Language, else
     * English. The web's SetLocale needs a session, which API requests lack.
     */
    public static function localized(): Middleware
    {
        return new Middleware(function (Request $request, Closure $next): Response {
            $supported = array_keys(Ui::LOCALES);
            $locale = $request->user()?->locale;
            if (! in_array($locale, $supported, true)) {
                $locale = $request->getPreferredLanguage($supported);
            }
            app()->setLocale(in_array($locale, $supported, true) ? (string) $locale : 'en');

            return $next($request);
        });
    }
}
