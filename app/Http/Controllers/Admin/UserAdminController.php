<?php

namespace App\Http\Controllers\Admin;

use App\Models\User;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Inertia\Inertia;

/** Grants or withdraws platform admin rights (is_admin is never mass-assigned). */
class UserAdminController extends AdminController
{
    public function store(User $user): RedirectResponse
    {
        if ($user->email_verified_at === null) {
            return $this->toast('error', ui('admin.error_unverified_admin'));
        }

        if (! $user->is_admin) {
            $user->forceFill(['is_admin' => true])->save();
        }

        return $this->toast('success', ui('admin.admin_granted', ['name' => $user->name]));
    }

    public function destroy(Request $request, User $user): RedirectResponse
    {
        $error = DB::transaction(function () use ($request, $user): ?string {
            // Lock the admin rows so two admins cannot remove each other at the same moment.
            $adminIds = User::query()->where('is_admin', true)->lockForUpdate()->pluck('id');

            if (! $adminIds->contains($user->id)) {
                return null;
            }
            if ($adminIds->count() <= 1) {
                return ui('admin.error_last_admin');
            }
            if ($user->is($request->user())) {
                return ui('admin.error_self_admin');
            }

            $user->forceFill(['is_admin' => false])->save();

            return null;
        });

        return $error !== null
            ? $this->toast('error', $error)
            : $this->toast('success', ui('admin.admin_revoked', ['name' => $user->name]));
    }

    private function toast(string $type, string $message): RedirectResponse
    {
        Inertia::flash('toast', ['type' => $type, 'message' => $message]);

        return back();
    }
}
