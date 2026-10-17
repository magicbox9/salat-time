<?php

namespace App\Http\Controllers\Claims;

use App\Http\Controllers\Controller;
use App\Models\MosqueClaim;
use Illuminate\Http\RedirectResponse;
use Illuminate\Support\Facades\Gate;
use Illuminate\Support\Facades\Storage;
use Inertia\Inertia;

/**
 * DELETE /me/claims/{claim} — the claimant withdraws a request still waiting
 * for review. The request and its supporting document are deleted (nothing
 * personal is kept), and a new request can be sent later.
 */
class WithdrawClaimController extends Controller
{
    public function __invoke(MosqueClaim $claim): RedirectResponse
    {
        Gate::authorize('withdraw-claim', $claim);

        $claim->loadMissing('mosque:id,name');
        $claim->delete();
        Storage::disk('local')->deleteDirectory('claims/'.$claim->id);

        Inertia::flash('toast', [
            'type' => 'success',
            'message' => ui('claims.withdrawn', ['mosque' => $claim->mosque?->name ?? '']),
        ]);

        return redirect()->route('claims.mine');
    }
}
