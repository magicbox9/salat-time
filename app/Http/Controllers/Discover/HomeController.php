<?php

namespace App\Http\Controllers\Discover;

use App\Http\Controllers\Controller;
use App\Http\Controllers\Discover\Support\MosqueCards;
use App\Http\Controllers\Hub\Support\HubPage;
use App\Support\ChosenMosque;
use App\Support\MosquePresenter;
use Illuminate\Http\Request;
use Inertia\Inertia;
use Inertia\Response;

/**
 * "/" is the visitor's own mosque (the hub with its prayer times) once one is
 * chosen, and the globe before that. "/explore" is always the globe, to find
 * or change a mosque.
 */
class HomeController extends Controller
{
    /** Country preselected in the search card (most imported mosques are in France). */
    public const INITIAL_COUNTRY = 'FR';

    public function home(Request $request, HubPage $hub): Response
    {
        $mosque = ChosenMosque::for($request);

        return $mosque
            ? $hub->render($request, $mosque, (string) ChosenMosque::source($request))
            : $this->globe($request);
    }

    public function explore(Request $request): Response
    {
        return $this->globe($request);
    }

    /** The globe. Signed-in visitors also get their saved mosques; everyone gets their own mosque. */
    private function globe(Request $request): Response
    {
        $user = $request->user();
        $favorites = $user ? MosqueCards::make(MosqueCards::favoritesOf($user), $user, withTimes: false) : [];
        $primary = collect($favorites)->firstWhere('is_primary', true);

        if (! $user && ($chosen = ChosenMosque::for($request))) {
            // A guest's own mosque (cookie): shown and flown to like a saved one.
            $chosen->loadCount('calendars');
            $primary = [...MosquePresenter::summary($chosen), 'is_favorite' => false, 'is_primary' => true, 'today' => null, 'tomorrow' => null];
        }

        return Inertia::render('home', [
            'favorites' => $favorites,
            'primary' => $primary,
            'initialCountry' => self::INITIAL_COUNTRY,
        ]);
    }
}
