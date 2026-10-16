<?php

namespace App\Http\Controllers\Claims;

use App\Http\Controllers\Controller;
use App\Models\MosqueClaim;
use Illuminate\Http\Request;
use Inertia\Inertia;
use Inertia\Response;

/** The signed-in user's requests to manage mosques, newest first. */
class MyClaimsController extends Controller
{
    public function __invoke(Request $request): Response
    {
        $claims = MosqueClaim::query()
            ->where('user_id', $request->user()->id)
            ->with('mosque:id,slug,name,city,verified_at')
            ->latest()
            ->orderByDesc('id')
            ->limit(100)
            ->get()
            ->map(fn (MosqueClaim $claim) => ClaimPresenter::forClaimant($claim))
            ->all();

        return Inertia::render('me/claims', ['claims' => $claims]);
    }
}
