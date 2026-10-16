<?php

namespace App\Http\Controllers\Admin;

use App\Models\Mosque;
use Illuminate\Http\RedirectResponse;
use Inertia\Inertia;

/**
 * Marks a mosque as verified once its documents and finances were checked
 * (a prerequisite for any future fundraising), or withdraws the mark.
 */
class MosqueVerificationController extends AdminController
{
    public function store(Mosque $mosque): RedirectResponse
    {
        if ($mosque->verified_at === null) {
            $mosque->forceFill(['verified_at' => now()])->save();
        }
        Inertia::flash('toast', ['type' => 'success', 'message' => ui('admin.mosque_verified', ['name' => $mosque->name])]);

        return back();
    }

    public function destroy(Mosque $mosque): RedirectResponse
    {
        $mosque->forceFill(['verified_at' => null])->save();
        Inertia::flash('toast', ['type' => 'success', 'message' => ui('admin.mosque_unverified', ['name' => $mosque->name])]);

        return back();
    }
}
