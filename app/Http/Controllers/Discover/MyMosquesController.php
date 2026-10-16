<?php

namespace App\Http\Controllers\Discover;

use App\Http\Controllers\Controller;
use App\Http\Controllers\Discover\Support\MosqueCards;
use Illuminate\Http\Request;
use Inertia\Inertia;
use Inertia\Response;

/** /me/mosques — the user's saved mosques, their own mosque first, with today's next prayer. */
class MyMosquesController extends Controller
{
    public function __invoke(Request $request): Response
    {
        $user = $request->user();

        return Inertia::render('me/mosques', [
            'mosques' => MosqueCards::make(MosqueCards::favoritesOf($user), $user),
        ]);
    }
}
