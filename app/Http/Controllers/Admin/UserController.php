<?php

namespace App\Http\Controllers\Admin;

use App\Models\User;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Http\Request;
use Inertia\Response;

/** Accounts on the platform, newest first. */
class UserController extends AdminController
{
    public function __invoke(Request $request): Response
    {
        $term = $this->searchTerm($request);
        $role = $this->choice($request, 'role', ['admin', 'manager', 'unverified']);
        $me = $request->user();

        $users = User::query()
            ->withCount('managedMosques')
            ->when($term, fn (Builder $q) => $q->where(fn (Builder $w) => $w
                ->where('name', 'ilike', $this->like($term))
                ->orWhere('email', 'ilike', $this->like($term))))
            ->when($role === 'admin', fn (Builder $q) => $q->where('is_admin', true))
            ->when($role === 'manager', fn (Builder $q) => $q->has('managedMosques'))
            ->when($role === 'unverified', fn (Builder $q) => $q->whereNull('email_verified_at'))
            ->latest()
            ->orderByDesc('id')
            ->paginate(25)
            ->withQueryString()
            ->through(fn (User $user) => [
                'id' => $user->id,
                'name' => $user->name,
                'email' => $user->email,
                'is_admin' => $user->is_admin,
                'verified' => $user->email_verified_at !== null,
                'joined_at' => $user->created_at?->toIso8601String(),
                'managed_count' => (int) $user->managed_mosques_count,
                'is_self' => $user->is($me),
            ]);

        return $this->page('admin/users/index', [
            'users' => $this->paginated($users),
            'filters' => ['q' => $term, 'role' => $role],
            'adminCount' => User::query()->where('is_admin', true)->count(),
        ]);
    }
}
