<?php

namespace App\Http\Controllers\Settings;

use App\Http\Controllers\Controller;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\ValidationException;
use Inertia\Inertia;
use Inertia\Response;
use Laravel\Sanctum\PersonalAccessToken;

/** Settings → Companion app: personal access tokens for the phone apps (API v1). */
class ApiTokenController extends Controller
{
    /** What a companion-app token may do. */
    public const ABILITIES = ['prayers:read', 'prayers:write'];

    public const MAX_TOKENS = 10;

    public const LIFETIME_DAYS = 365;

    public function index(Request $request): Response
    {
        $tokens = $request->user()->tokens()
            ->latest()
            ->get(['id', 'name', 'abilities', 'last_used_at', 'expires_at', 'created_at'])
            ->map(fn (PersonalAccessToken $token) => [
                'id' => $token->id,
                'name' => $token->name,
                'last_used_at' => $token->last_used_at?->toIso8601String(),
                'expires_at' => $token->expires_at?->toIso8601String(),
                'created_at' => $token->created_at?->toIso8601String(),
                'expired' => $token->expires_at !== null && $token->expires_at->isPast(),
            ]);

        return Inertia::render('settings/api-tokens', [
            'tokens' => $tokens,
            'maxTokens' => self::MAX_TOKENS,
            'lifetimeDays' => self::LIFETIME_DAYS,
            'apiBase' => url('/api/v1'),
        ]);
    }

    public function store(Request $request): RedirectResponse
    {
        $data = $request->validate([
            'name' => ['required', 'string', 'min:2', 'max:60'],
        ]);
        $user = $request->user();
        if ($user->tokens()->count() >= self::MAX_TOKENS) {
            throw ValidationException::withMessages(['name' => ui('prayers.tokens_limit', ['max' => self::MAX_TOKENS])]);
        }

        $token = $user->createToken(trim($data['name']), self::ABILITIES, now()->addDays(self::LIFETIME_DAYS));

        // The plain token is shown once, right after creation, and never stored readable.
        Inertia::flash([
            'newToken' => ['id' => $token->accessToken->id, 'name' => $token->accessToken->name, 'token' => $token->plainTextToken],
            'toast' => ['type' => 'success', 'message' => ui('prayers.tokens_created')],
        ]);

        return to_route('api-tokens.index');
    }

    public function destroy(Request $request, string $token): RedirectResponse
    {
        // Only the signed-in person's own tokens can be found here.
        $request->user()->tokens()->whereKey((int) $token)->firstOrFail()->delete();
        Inertia::flash('toast', ['type' => 'info', 'message' => ui('prayers.tokens_revoked')]);

        return to_route('api-tokens.index');
    }
}
