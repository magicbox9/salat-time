<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Claims\ClaimPresenter;
use App\Http\Controllers\Controller;
use App\Models\Mosque;
use App\Models\MosqueClaim;
use App\Models\User;
use Carbon\CarbonImmutable;
use Illuminate\Contracts\Pagination\LengthAwarePaginator;
use Illuminate\Http\Request;
use Illuminate\Support\Str;
use Inertia\Inertia;
use Inertia\Response;

/** Shared helpers for the admin pages (all routes sit behind 'can:admin'). */
abstract class AdminController extends Controller
{
    /**
     * Renders an admin page with the pending-claims count shown in the admin menu.
     *
     * @param  array<string, mixed>  $props
     */
    protected function page(string $component, array $props = []): Response
    {
        return Inertia::render($component, [
            ...$props,
            'pendingClaimsCount' => fn () => MosqueClaim::query()->where('status', MosqueClaim::PENDING)->count(),
        ]);
    }

    /**
     * The paginator fields the React pagination needs.
     *
     * @param  LengthAwarePaginator<int, mixed>  $paginator
     * @return array<string, mixed>
     */
    protected function paginated(LengthAwarePaginator $paginator): array
    {
        return [
            'data' => $paginator->items(),
            'current_page' => $paginator->currentPage(),
            'last_page' => $paginator->lastPage(),
            'total' => $paginator->total(),
            'from' => $paginator->firstItem(),
            'to' => $paginator->lastItem(),
            'prev_page_url' => $paginator->previousPageUrl(),
            'next_page_url' => $paginator->nextPageUrl(),
        ];
    }

    /**
     * People allowed to run a mosque's page, with who granted the right.
     *
     * @return array<int, array<string, mixed>>
     */
    protected function managersOf(Mosque $mosque): array
    {
        $managers = User::query()
            ->join('mosque_managers', 'mosque_managers.user_id', '=', 'users.id')
            ->leftJoin('users as grantors', 'grantors.id', '=', 'mosque_managers.granted_by')
            ->where('mosque_managers.mosque_id', $mosque->id)
            ->orderBy('mosque_managers.created_at')
            ->get([
                'users.id', 'users.name', 'users.email', 'mosque_managers.role',
                'mosque_managers.created_at as managed_since', 'grantors.name as granted_by_name',
            ]);

        return $managers->map(function (User $user): array {
            $since = $user->getAttribute('managed_since');

            return [
                'id' => $user->id,
                'name' => $user->name,
                'email' => $user->email,
                'role' => (string) $user->getAttribute('role'),
                'granted_by' => $user->getAttribute('granted_by_name'),
                'since' => is_string($since) ? ClaimPresenter::iso(CarbonImmutable::parse($since)) : null,
            ];
        })->values()->all();
    }

    /** A trimmed search term (at most 100 characters), or null. */
    protected function searchTerm(Request $request): ?string
    {
        $value = $request->query('q');
        if (! is_string($value)) {
            return null;
        }
        $term = Str::of($value)->squish()->limit(100, '')->toString();

        return $term === '' ? null : $term;
    }

    /**
     * A query-string filter limited to known values (anything else is ignored).
     *
     * @param  list<string>  $allowed
     */
    protected function choice(Request $request, string $key, array $allowed): ?string
    {
        $value = $request->query($key);

        return is_string($value) && in_array($value, $allowed, true) ? $value : null;
    }

    /** Escapes LIKE wildcards in user input. */
    protected function like(string $term): string
    {
        return '%'.addcslashes($term, '%_\\').'%';
    }
}
