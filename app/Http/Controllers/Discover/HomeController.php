<?php

namespace App\Http\Controllers\Discover;

use App\Http\Controllers\Controller;
use App\Http\Controllers\Discover\Support\MosqueCards;
use Illuminate\Http\Request;
use Inertia\Inertia;
use Inertia\Response;

/** The landing globe. Signed-in visitors also get their saved mosques and their own mosque. */
class HomeController extends Controller
{
    /** Country preselected in the search card (most imported mosques are in France). */
    public const INITIAL_COUNTRY = 'FR';

    public function __invoke(Request $request): Response
    {
        $user = $request->user();
        $favorites = $user ? MosqueCards::make(MosqueCards::favoritesOf($user), $user, withTimes: false) : [];

        return Inertia::render('home', [
            'favorites' => $favorites,
            'primary' => collect($favorites)->firstWhere('is_primary', true),
            'initialCountry' => self::INITIAL_COUNTRY,
        ]);
    }
}
