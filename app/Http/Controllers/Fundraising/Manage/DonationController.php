<?php

namespace App\Http\Controllers\Fundraising\Manage;

use App\Http\Controllers\Controller;
use App\Models\Campaign;
use App\Models\Donation;
use App\Models\Mosque;
use App\Services\Fundraising\AbandonedCheckouts;
use App\Services\Fundraising\DonationCsv;
use App\Services\Fundraising\DonationLedger;
use App\Support\MosquePresenter;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Inertia\Inertia;
use Inertia\Response;
use Symfony\Component\HttpFoundation\StreamedResponse;

/**
 * /manage/{mosque}/donations — every donation to the mosque's campaigns:
 * filters, CSV export, and the bank transfers to confirm (or cancel) once
 * the mosque checked its account.
 */
class DonationController extends Controller
{
    private const STATUSES = ['pending', 'completed', 'cancelled', 'failed', 'refunded'];

    public function index(Request $request, Mosque $mosque): Response
    {
        $filters = $this->filters($request, $mosque);
        $donations = $this->query($mosque, $filters)
            ->with('campaign:id,slug,title')
            ->latest()
            ->orderByDesc('id')
            ->paginate(25)
            ->withQueryString()
            ->through(fn (Donation $d) => ManageDonationRow::from($d));

        $totals = Donation::query()->where('mosque_id', $mosque->id)
            ->selectRaw("COALESCE(SUM(amount) FILTER (WHERE status = 'completed'), 0) AS raised")
            ->selectRaw("COALESCE(SUM(amount) FILTER (WHERE status = 'pending' AND method = 'bank'), 0) AS pledged")
            ->selectRaw("COUNT(*) FILTER (WHERE status = 'pending' AND method = 'bank') AS to_confirm")
            ->first();

        return Inertia::render('fundraising/donations', [
            'mosque' => MosquePresenter::summary($mosque),
            'donations' => $donations,
            'filters' => [
                'campaign' => $filters['campaign']?->slug,
                'status' => $filters['status'],
                'method' => $filters['method'],
            ],
            'campaigns' => Campaign::query()->where('mosque_id', $mosque->id)->orderByDesc('id')->get(['id', 'slug', 'title'])
                ->map(fn (Campaign $c) => ['slug' => $c->slug, 'title' => $c->title])->all(),
            'totals' => [
                'raised' => (int) ($totals->raised ?? 0),
                'pledged' => (int) ($totals->pledged ?? 0),
                'to_confirm' => (int) ($totals->to_confirm ?? 0),
                'currency' => config('fundraising.currency'),
            ],
        ]);
    }

    /** The mosque saw the transfer on its account: the donation counts as raised. */
    public function confirm(Request $request, Mosque $mosque, int $donation, DonationLedger $ledger): RedirectResponse
    {
        $record = $this->bankDonation($mosque, $donation);
        $done = $ledger->complete($record, ['confirmed_by' => $request->user()->id, 'confirmed_at' => now()]);

        return $this->back($done, 'fundraising.pledge_confirmed');
    }

    public function cancel(Mosque $mosque, int $donation, DonationLedger $ledger): RedirectResponse
    {
        $done = $ledger->cancel($this->bankDonation($mosque, $donation));

        return $this->back($done, 'fundraising.pledge_cancelled');
    }

    public function export(Request $request, Mosque $mosque, DonationCsv $csv): StreamedResponse
    {
        $filters = $this->filters($request, $mosque);
        $name = 'donations-'.$mosque->slug.'-'.now()->setTimezone($mosque->timezone)->format('Y-m-d').'.csv';

        return $csv->download($this->query($mosque, $filters), $name, $mosque->timezone);
    }

    /**
     * Only pending bank transfers to campaigns of this mosque can be confirmed or cancelled.
     */
    private function bankDonation(Mosque $mosque, int $id): Donation
    {
        return Donation::query()
            ->where('mosque_id', $mosque->id)
            ->where('method', 'bank')
            ->findOrFail($id);
    }

    private function back(bool $done, string $message): RedirectResponse
    {
        Inertia::flash('toast', [
            'type' => $done ? 'success' : 'error',
            'message' => ui($done ? $message : 'fundraising.pledge_already_settled'),
        ]);

        return back(303);
    }

    /**
     * @return array{campaign: Campaign|null, status: string|null, method: string|null}
     */
    private function filters(Request $request, Mosque $mosque): array
    {
        $slug = $request->query('campaign');
        $status = $request->query('status');
        $method = $request->query('method');

        return [
            'campaign' => is_string($slug) && preg_match('/^[a-z0-9-]{1,140}$/', $slug)
                ? Campaign::withTrashed()->where('mosque_id', $mosque->id)->where('slug', $slug)->first()
                : null,
            'status' => is_string($status) && in_array($status, self::STATUSES, true) ? $status : null,
            'method' => is_string($method) && in_array($method, Donation::METHODS, true) ? $method : null,
        ];
    }

    /**
     * Donations of the mosque, without PayPal checkouts the donor abandoned.
     *
     * @param  array{campaign: Campaign|null, status: string|null, method: string|null}  $filters
     * @return Builder<Donation>
     */
    private function query(Mosque $mosque, array $filters): Builder
    {
        return AbandonedCheckouts::exclude(Donation::query()->where('mosque_id', $mosque->id))
            ->when($filters['campaign'], fn (Builder $q, Campaign $c) => $q->where('campaign_id', $c->id))
            ->when($filters['status'], fn (Builder $q, string $s) => $q->where('status', $s))
            ->when($filters['method'], fn (Builder $q, string $m) => $q->where('method', $m));
    }
}
