<?php

namespace App\Http\Controllers\Hub;

use App\Http\Controllers\Controller;
use App\Http\Controllers\Discover\Support\MyMosque;
use App\Models\Mosque;
use App\Models\User;
use App\Support\ChosenMosque;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Cookie;
use Illuminate\Validation\ValidationException;
use Inertia\Inertia;

/**
 * POST /my-mosque {slug} — "Make it my mosque", for everyone: a signed-in
 * user's primary saved mosque, a guest's encrypted cookie. The visitor is
 * then taken to "/", which opens on that mosque's prayer times.
 * DELETE /my-mosque — no own mosque any more ("/" shows the globe again).
 */
class ChosenMosqueController extends Controller
{
    public function store(Request $request): JsonResponse|RedirectResponse
    {
        $data = $request->validate([
            'slug' => ['required', 'string', 'max:255', 'regex:/^[a-z0-9-]+$/'],
        ]);
        $mosque = Mosque::query()->where('slug', $data['slug'])->first()
            ?? throw ValidationException::withMessages(['slug' => ui('hub.mosque_not_found')]);
        $user = $request->user();

        if ($user instanceof User) {
            MyMosque::choose($user, $mosque);
        } else {
            Cookie::queue(ChosenMosque::cookie($mosque));
        }

        return $this->answer($request, $mosque, ui('discover.primary_set', ['name' => $mosque->name]), route('home'));
    }

    public function destroy(Request $request): JsonResponse|RedirectResponse
    {
        $user = $request->user();
        if ($user instanceof User) {
            MyMosque::clear($user);
        }
        Cookie::queue(ChosenMosque::forget());

        return $this->answer($request, null, ui('hub.cleared'), route('explore'));
    }

    private function answer(Request $request, ?Mosque $mosque, string $message, string $to): JsonResponse|RedirectResponse
    {
        if ($request->expectsJson() && ! $request->header('X-Inertia')) {
            return response()->json([
                'slug' => $mosque?->slug,
                'chosen' => $mosque !== null,
                'message' => $message,
                'redirect' => $to,
            ]);
        }

        Inertia::flash('toast', ['type' => 'success', 'message' => $message]);

        return redirect()->to($to);
    }
}
