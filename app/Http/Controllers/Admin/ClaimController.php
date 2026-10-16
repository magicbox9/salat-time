<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Claims\ClaimPresenter;
use App\Models\Mosque;
use App\Models\MosqueClaim;
use App\Models\User;
use App\Support\MosquePresenter;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Http\Request;
use Inertia\Response;

/** The review queue of requests to manage a mosque. */
class ClaimController extends AdminController
{
    private const STATUSES = [MosqueClaim::PENDING, MosqueClaim::APPROVED, MosqueClaim::REJECTED];

    public function index(Request $request): Response
    {
        $status = $this->choice($request, 'status', [...self::STATUSES, 'all']) ?? MosqueClaim::PENDING;
        $term = $this->searchTerm($request);

        $claims = MosqueClaim::query()
            ->with(['mosque:id,slug,name,city,verified_at', 'user:id,name,email'])
            ->when($status !== 'all', fn (Builder $q) => $q->where('status', $status))
            ->when($term, fn (Builder $q) => $q->where(function (Builder $w) use ($term) {
                $like = $this->like($term);
                $w->whereHas('user', fn (Builder $u) => $u->where('name', 'ilike', $like)->orWhere('email', 'ilike', $like))
                    ->orWhereHas('mosque', fn (Builder $m) => $m->where('search_name', 'like', $this->like(Mosque::searchKey($term))));
            }))
            // Pending requests are reviewed oldest first; decided ones newest first.
            ->when($status === MosqueClaim::PENDING, fn (Builder $q) => $q->oldest(), fn (Builder $q) => $q->latest())
            ->orderBy('id')
            ->paginate(20)
            ->withQueryString()
            ->through(fn (MosqueClaim $claim) => ClaimPresenter::forAdminList($claim));

        $counts = MosqueClaim::query()
            ->selectRaw('status, count(*) as total')
            ->groupBy('status')
            ->pluck('total', 'status');

        return $this->page('admin/claims/index', [
            'claims' => $this->paginated($claims),
            'filters' => ['status' => $status, 'q' => $term],
            'counts' => [
                ...collect(self::STATUSES)->mapWithKeys(fn ($s) => [$s => (int) ($counts[$s] ?? 0)])->all(),
                'all' => (int) $counts->sum(),
            ],
        ]);
    }

    public function show(MosqueClaim $claim): Response
    {
        $claim->load(['user', 'reviewer:id,name']);
        /** @var Mosque $mosque */
        $mosque = Mosque::query()->withCount('calendars')->findOrFail($claim->mosque_id);
        $claim->setRelation('mosque', $mosque);
        /** @var User $claimant */
        $claimant = $claim->getRelation('user');

        $otherClaims = MosqueClaim::query()
            ->where('mosque_id', $mosque->id)
            ->whereKeyNot($claim->id)
            ->with('user:id,name,email')
            ->latest()
            ->limit(10)
            ->get()
            ->map(fn (MosqueClaim $other) => ClaimPresenter::forAdminList($other))
            ->all();

        return $this->page('admin/claims/show', [
            'claim' => ClaimPresenter::forAdmin($claim),
            'claimant' => [
                'id' => $claimant->id,
                'name' => $claimant->name,
                'email' => $claimant->email,
                'verified' => $claimant->email_verified_at !== null,
                'joined_at' => ClaimPresenter::iso($claimant->created_at),
                'is_admin' => $claimant->is_admin,
                'managed_count' => $claimant->managedMosques()->count(),
                'claims_count' => MosqueClaim::query()->where('user_id', $claimant->id)->count(),
            ],
            'mosque' => [
                ...MosquePresenter::summary($mosque),
                'association' => $mosque->getAttribute('association'),
                'phone' => $mosque->getAttribute('phone'),
                'email' => $mosque->getAttribute('email'),
                'website' => $mosque->getAttribute('website'),
            ],
            'managers' => $this->managersOf($mosque),
            'otherClaims' => $otherClaims,
        ]);
    }
}
