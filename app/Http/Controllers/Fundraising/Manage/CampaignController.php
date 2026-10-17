<?php

namespace App\Http\Controllers\Fundraising\Manage;

use App\Http\Controllers\Controller;
use App\Http\Controllers\Fundraising\Requests\SaveCampaignRequest;
use App\Http\Controllers\Manage\Support\ImageStore;
use App\Models\Campaign;
use App\Models\Donation;
use App\Models\Mosque;
use App\Services\Fundraising\AbandonedCheckouts;
use App\Services\Fundraising\CampaignEligibility;
use App\Services\Fundraising\CampaignPresenter;
use App\Services\Fundraising\CampaignProgress;
use App\Services\Fundraising\CampaignSlug;
use App\Services\Fundraising\ModelDate;
use App\Services\Fundraising\PaymentMethods;
use App\Services\Payments\PayPalClient;
use App\Support\MosquePresenter;
use Carbon\CarbonImmutable;
use Illuminate\Http\RedirectResponse;
use Inertia\Inertia;
use Inertia\Response;
use Throwable;

/** /manage/{mosque}/campaigns — a mosque's campaigns: list, write, edit, delete. */
class CampaignController extends Controller
{
    /** Statuses whose content can still change. Title and kind are fixed once approved. */
    private const EDITABLE = ['draft', 'pending', 'rejected', 'active'];

    public function __construct(
        private readonly CampaignEligibility $eligibility,
        private readonly PaymentMethods $methods,
    ) {}

    public function index(Mosque $mosque, PayPalClient $paypal): Response
    {
        $campaigns = Campaign::query()->where('mosque_id', $mosque->id)->latest()->orderByDesc('id')->get()
            ->map(function (Campaign $campaign) use ($mosque) {
                $campaign->setRelation('mosque', $mosque);

                return [...CampaignPresenter::card($campaign), 'review_note' => $campaign->review_note];
            });

        return Inertia::render('fundraising/index', [
            'mosque' => MosquePresenter::summary($mosque),
            'campaigns' => $campaigns->values()->all(),
            'problems' => $this->eligibility->mosqueProblems($mosque),
            'allowable' => $this->methods->allowable($mosque),
            'paypalEnabled' => $paypal->isConfigured(),
            'pendingTransfers' => Donation::query()->where('mosque_id', $mosque->id)
                ->where('method', 'bank')->where('status', 'pending')->count(),
        ]);
    }

    public function create(Mosque $mosque, PayPalClient $paypal): Response
    {
        return $this->form($mosque, null, $paypal);
    }

    public function store(SaveCampaignRequest $request, Mosque $mosque, ImageStore $images): RedirectResponse
    {
        $campaign = new Campaign;
        $campaign->forceFill([
            'mosque_id' => $mosque->id,
            'created_by' => $request->user()->id,
            'slug' => CampaignSlug::for((string) $request->validated('title'), $mosque->name),
            'currency' => config('fundraising.currency'),
            'status' => 'draft',
        ]);
        $this->fill($campaign, $request, $mosque, $images);
        Inertia::flash('toast', ['type' => 'success', 'message' => ui('fundraising.campaign_created')]);

        return to_route('manage.campaigns.show', [$mosque, $campaign]);
    }

    public function show(Mosque $mosque, Campaign $campaign): Response
    {
        $campaign->setRelation('mosque', $mosque);
        $recent = AbandonedCheckouts::exclude(Donation::query()->where('campaign_id', $campaign->id))
            ->latest()->orderByDesc('id')->limit(8)->get()
            ->map(fn (Donation $d) => ManageDonationRow::from($d));

        return Inertia::render('fundraising/campaign', [
            'mosque' => MosquePresenter::summary($mosque),
            'campaign' => [...CampaignPresenter::card($campaign), 'review_note' => $campaign->review_note],
            'updates' => CampaignPresenter::updates($campaign, 100),
            'donations' => $recent->all(),
            'problems' => in_array($campaign->status, ['draft', 'rejected'], true)
                ? $this->eligibility->submissionProblems($campaign, $mosque)
                : [],
        ]);
    }

    public function edit(Mosque $mosque, Campaign $campaign, PayPalClient $paypal): Response|RedirectResponse
    {
        if (! in_array($campaign->status, self::EDITABLE, true)) {
            return $this->locked($mosque, $campaign);
        }

        return $this->form($mosque, $campaign, $paypal);
    }

    public function update(SaveCampaignRequest $request, Mosque $mosque, Campaign $campaign, ImageStore $images): RedirectResponse
    {
        if (! in_array($campaign->status, self::EDITABLE, true)) {
            return $this->locked($mosque, $campaign);
        }
        $this->fill($campaign, $request, $mosque, $images);
        Inertia::flash('toast', ['type' => 'success', 'message' => ui('fundraising.campaign_saved')]);

        return to_route('manage.campaigns.show', [$mosque, $campaign]);
    }

    /** Only a campaign that never received a donation (or a pledge) can be deleted. */
    public function destroy(Mosque $mosque, Campaign $campaign, ImageStore $images): RedirectResponse
    {
        if ($campaign->status === 'active'
            || AbandonedCheckouts::exclude(Donation::query()->where('campaign_id', $campaign->id))->exists()) {
            Inertia::flash('toast', ['type' => 'error', 'message' => ui('fundraising.campaign_cannot_delete')]);

            return back();
        }
        $images->delete($mosque, $campaign->cover_path);
        $campaign->forceFill(['cover_path' => null])->save();
        $campaign->delete();
        CampaignProgress::forget($campaign);
        Inertia::flash('toast', ['type' => 'success', 'message' => ui('fundraising.campaign_deleted')]);

        return to_route('manage.campaigns.index', $mosque);
    }

    private function form(Mosque $mosque, ?Campaign $campaign, PayPalClient $paypal): Response
    {
        $zone = $mosque->timezone;

        return Inertia::render('fundraising/campaign-form', [
            'mosque' => MosquePresenter::summary($mosque),
            'campaign' => $campaign ? [
                'slug' => $campaign->slug,
                'status' => $campaign->status,
                'kind' => $campaign->kind,
                'title' => $campaign->title,
                'summary' => $campaign->summary,
                'story' => $campaign->story,
                'cover_url' => CampaignPresenter::coverUrl($campaign->cover_path),
                'goal' => intdiv((int) $campaign->goal_amount, 100),
                'starts_on' => ModelDate::of($campaign, 'starts_at')?->setTimezone($zone)->format('Y-m-d') ?? '',
                'ends_on' => ModelDate::of($campaign, 'ends_at')?->setTimezone($zone)->format('Y-m-d') ?? '',
                'allow_paypal' => (bool) $campaign->allow_paypal,
                'allow_bank' => (bool) $campaign->allow_bank,
                'show_donor_names' => (bool) $campaign->show_donor_names,
                'locked' => in_array($campaign->status, ['active'], true),
            ] : null,
            'kinds' => Campaign::KINDS,
            'allowable' => $this->methods->allowable($mosque),
            'paypalEnabled' => $paypal->isConfigured(),
            'problems' => $this->eligibility->mosqueProblems($mosque),
        ]);
    }

    private function fill(Campaign $campaign, SaveCampaignRequest $request, Mosque $mosque, ImageStore $images): void
    {
        $data = $request->validated();
        $approved = $campaign->exists && $campaign->status === 'active';
        $allowable = $this->methods->allowable($mosque);

        $campaign->fill([
            'summary' => trim((string) $data['summary']),
            'story' => trim((string) $data['story']),
            'goal_amount' => (int) $data['goal'] * 100,
            'starts_at' => $this->day($data['starts_on'] ?? null, $mosque->timezone, false),
            'ends_at' => $this->day($data['ends_on'] ?? null, $mosque->timezone, true),
            'allow_paypal' => $request->boolean('allow_paypal') && $allowable['paypal'],
            'allow_bank' => $request->boolean('allow_bank') && $allowable['bank'],
            'show_donor_names' => $request->boolean('show_donor_names'),
        ]);
        if (! $approved) {
            $campaign->fill(['kind' => $data['kind'], 'title' => trim((string) $data['title'])]);
        }

        $old = $campaign->cover_path;
        $stored = null;
        if ($request->hasFile('cover')) {
            $campaign->cover_path = $stored = $images->store($mosque, $request->file('cover'), 'cover', 'campaigns', 2000);
        } elseif ($request->boolean('remove_cover')) {
            $campaign->cover_path = null;
        }

        try {
            $campaign->save();
        } catch (Throwable $e) {
            $images->delete($mosque, $stored);

            throw $e;
        }
        if ($old !== null && $old !== $campaign->cover_path) {
            $images->delete($mosque, $old);
        }
        CampaignProgress::forget($campaign);
    }

    /** "2026-11-30" in the mosque's zone → the start (or end) of that day, in UTC. */
    private function day(?string $date, string $zone, bool $endOfDay): ?CarbonImmutable
    {
        if (! $date) {
            return null;
        }
        $day = CarbonImmutable::createFromFormat('!Y-m-d', $date, $zone);

        return ($endOfDay ? $day->endOfDay() : $day->startOfDay())->utc();
    }

    private function locked(Mosque $mosque, Campaign $campaign): RedirectResponse
    {
        Inertia::flash('toast', ['type' => 'error', 'message' => ui('fundraising.campaign_locked')]);

        return to_route('manage.campaigns.show', [$mosque, $campaign]);
    }
}
