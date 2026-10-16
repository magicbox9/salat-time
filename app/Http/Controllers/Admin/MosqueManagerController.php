<?php

namespace App\Http\Controllers\Admin;

use App\Models\Mosque;
use App\Models\User;
use Illuminate\Http\RedirectResponse;
use Inertia\Inertia;

/** Withdraws someone's right to manage a mosque's page. */
class MosqueManagerController extends AdminController
{
    public function destroy(Mosque $mosque, User $user): RedirectResponse
    {
        abort_unless($mosque->managers()->whereKey($user->id)->exists(), 404);

        $mosque->managers()->detach($user->id);
        Inertia::flash('toast', [
            'type' => 'success',
            'message' => ui('admin.manager_revoked', ['name' => $user->name, 'mosque' => $mosque->name]),
        ]);

        return back();
    }
}
