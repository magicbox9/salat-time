<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Claims\ClaimPresenter;
use App\Models\Mosque;
use App\Models\MosqueClaim;
use App\Support\MosquePresenter;
use DateTimeZone;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Inertia\Inertia;
use Inertia\Response;

/** Find, correct and verify mosque records. */
class MosqueController extends AdminController
{
    public const SOURCES = ['mawaqit', 'directory', 'osm', 'manual'];

    public function index(Request $request): Response
    {
        $term = $this->searchTerm($request);
        $times = $this->choice($request, 'times', ['yes', 'no']);
        $verified = $this->choice($request, 'verified', ['yes', 'no']);
        $source = $this->choice($request, 'source', self::SOURCES);

        $mosques = Mosque::query()
            ->withCount(['calendars', 'managers'])
            ->when($term, fn (Builder $q) => $q->search($term), fn (Builder $q) => $q->orderBy('name'))
            ->when($times === 'yes', fn (Builder $q) => $q->has('calendars'))
            ->when($times === 'no', fn (Builder $q) => $q->doesntHave('calendars'))
            ->when($verified === 'yes', fn (Builder $q) => $q->whereNotNull('verified_at'))
            ->when($verified === 'no', fn (Builder $q) => $q->whereNull('verified_at'))
            ->when($source, fn (Builder $q) => $q->where('source', $source))
            ->orderBy('id')
            ->paginate(25)
            ->withQueryString()
            ->through(fn (Mosque $mosque) => [
                ...MosquePresenter::summary($mosque),
                'managers_count' => (int) $mosque->managers_count,
            ]);

        return $this->page('admin/mosques/index', [
            'mosques' => $this->paginated($mosques),
            'filters' => ['q' => $term, 'times' => $times, 'verified' => $verified, 'source' => $source],
            'sources' => self::SOURCES,
        ]);
    }

    public function edit(Mosque $mosque): Response
    {
        $mosque->loadCount('calendars');

        $pendingClaims = MosqueClaim::query()
            ->where('mosque_id', $mosque->id)
            ->where('status', MosqueClaim::PENDING)
            ->with('user:id,name,email')
            ->oldest()
            ->limit(50) // the full list stays one click away in the review queue
            ->get()
            ->map(fn (MosqueClaim $claim) => ClaimPresenter::forAdminList($claim))
            ->all();

        // A legacy zone name (e.g. Europe/Kiev) is not in the current list: keep it
        // selectable, or the form would silently switch the mosque to the first zone.
        $timezones = DateTimeZone::listIdentifiers();
        if (! in_array($mosque->timezone, $timezones, true)) {
            array_unshift($timezones, $mosque->timezone);
        }

        return $this->page('admin/mosques/edit', [
            'mosque' => [
                ...MosquePresenter::summary($mosque),
                'verified_at' => ClaimPresenter::iso($mosque->verified_at),
            ],
            'managers' => $this->managersOf($mosque),
            'pendingClaims' => $pendingClaims,
            'timezones' => $timezones,
        ]);
    }

    public function update(Request $request, Mosque $mosque): RedirectResponse
    {
        $data = $request->validate([
            'name' => ['required', 'string', 'max:200'],
            'address' => ['nullable', 'string', 'max:300'],
            'postcode' => ['nullable', 'string', 'max:16'],
            'city' => ['nullable', 'string', 'max:120'],
            'latitude' => ['required', 'numeric', 'between:-90,90'],
            'longitude' => ['required', 'numeric', 'between:-180,180'],
            // Legacy aliases stay valid so a record holding one can still be saved.
            'timezone' => ['required', 'string', 'timezone:all_with_bc'],
        ], [
            'required' => ui('admin.v_required'),
            'string' => ui('admin.v_required'),
            'max' => ui('admin.v_max'),
            'numeric' => ui('admin.v_number'),
            'between' => ui('admin.v_between'),
            'timezone' => ui('admin.v_timezone'),
        ]);

        $mosque->fill([
            'name' => trim($data['name']),
            'address' => $this->clean($data['address'] ?? null),
            'postcode' => $this->clean($data['postcode'] ?? null),
            'city' => $this->clean($data['city'] ?? null),
            'latitude' => round((float) $data['latitude'], 6),
            'longitude' => round((float) $data['longitude'], 6),
            'timezone' => $data['timezone'],
        ])->save();

        Inertia::flash('toast', ['type' => 'success', 'message' => ui('admin.mosque_saved')]);

        return to_route('admin.mosques.edit', $mosque);
    }

    private function clean(?string $value): ?string
    {
        $value = $value === null ? null : trim($value);

        return $value === '' ? null : $value;
    }
}
