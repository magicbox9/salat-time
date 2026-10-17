<?php

namespace App\Http\Controllers\Admin\Fundraising;

use App\Http\Controllers\Admin\AdminController;
use App\Http\Controllers\MosquePage\Support\PlainText;
use App\Models\Campaign;
use App\Models\Mosque;
use App\Models\User;
use App\Notifications\CampaignApproved;
use App\Notifications\CampaignRejected;
use App\Services\Fundraising\CampaignEligibility;
use App\Services\Fundraising\CampaignPresenter;
use App\Services\Fundraising\CampaignProgress;
use App\Services\Fundraising\FundraisingMail;
use App\Services\Fundraising\PaymentMethods;
use App\Services\Fundraising\ReviewVersion;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Inertia\Inertia;
use Inertia\Response;

/**
 * /admin/fundraising/campaigns — every campaign is approved by an admin
 * before it is public. Approval needs a verified mosque and verified
 * accounts for the ways of giving the campaign allows.
 */
class CampaignReviewController extends AdminController
{
    /** A note of the reviewing admin, shown to the mosque's managers. */
    private const NOTE = ['nullable', 'string', PlainText::RULE, 'max:1000'];

    public function index(Request $request): Response
    {
        $status = $this->choice($request, 'status', [...Campaign::STATUSES, 'all']) ?? 'pending';
        $query = Campaign::query()
            ->when($status !== 'all', fn (Builder $q) => $q->where('status', $status))
            ->with('mosque:id,slug,name,city,country_code,verified_at,logo_path')
            ->orderByDesc('updated_at');

        return $this->page('admin/fundraising/campaigns', [
            'campaigns' => $this->paginated($query->paginate(20)->withQueryString()->through(fn (Campaign $c) => CampaignPresenter::card($c))),
            'status' => $status,
        ]);
    }

    public function show(Campaign $campaign, CampaignEligibility $eligibility, PaymentMethods $methods): Response
    {
        $campaign->load('mosque.payoutMethods');
        $mosque = CampaignPresenter::mosqueOf($campaign);
        $reviewer = $campaign->reviewed_by ? User::query()->find($campaign->reviewed_by, ['id', 'name']) : null;

        return $this->page('admin/fundraising/campaign', [
            'campaign' => [
                ...CampaignPresenter::detail($campaign),
                'review_note' => $campaign->review_note,
                'reviewed_by' => $reviewer?->name,
                'reviewed_at' => CampaignPresenter::iso($campaign->reviewed_at),
                'allow_paypal' => (bool) $campaign->allow_paypal,
                'allow_bank' => (bool) $campaign->allow_bank,
                'version' => ReviewVersion::campaign($campaign),
            ],
            'problems' => $mosque ? $eligibility->submissionProblems($campaign, $mosque) : ['mosque_unverified'],
            'allowable' => $mosque ? $methods->allowable($mosque) : ['paypal' => false, 'bank' => false],
        ]);
    }

    /**
     * Publishes the campaign exactly as the admin reviewed it: the page sends
     * back the version it showed, and an edit made by the mosque since then
     * stops the approval (the admin reloads and reviews the new text).
     */
    public function approve(Request $request, Campaign $campaign, CampaignEligibility $eligibility, FundraisingMail $mail): RedirectResponse
    {
        $data = $request->validate(['note' => self::NOTE], [], ['note' => ui('fundraising.admin_note')]);
        if (! ReviewVersion::matches(ReviewVersion::campaign($campaign), $request->input('version'))) {
            Inertia::flash('toast', ['type' => 'error', 'message' => ui('fundraising.admin_campaign_changed')]);

            return back(303);
        }
        $mosque = Mosque::query()->findOrFail($campaign->mosque_id);
        $problems = $eligibility->submissionProblems($campaign, $mosque);
        if ($problems !== []) {
            Inertia::flash('toast', ['type' => 'error', 'message' => ui('fundraising.problem_'.$problems[0])]);

            return back(303);
        }

        $version = ReviewVersion::campaign($campaign);
        $decided = $this->decide($campaign, 'pending', fn (Campaign $locked) => ReviewVersion::campaign($locked) === $version ? [
            'status' => 'active',
            'starts_at' => $locked->starts_at ?? now(),
        ] : null, $request->user(), $data['note'] ?? null);

        if ($decided) {
            $mail->decision($campaign, new CampaignApproved($campaign));
        }

        return $this->done($decided, 'fundraising.admin_campaign_approved');
    }

    public function reject(Request $request, Campaign $campaign, FundraisingMail $mail): RedirectResponse
    {
        $data = $request->validate(['note' => ['required', 'string', PlainText::RULE, 'min:3', 'max:1000']], [
            'note.required' => ui('fundraising.admin_note_required'),
            'note.min' => ui('fundraising.admin_note_required'),
        ], ['note' => ui('fundraising.admin_note')]);

        $decided = $this->decide($campaign, 'pending', fn () => ['status' => 'rejected'], $request->user(), $data['note']);
        if ($decided) {
            $mail->decision($campaign, new CampaignRejected($campaign));
        }

        return $this->done($decided, 'fundraising.admin_campaign_rejected');
    }

    /** An admin stops an open campaign (e.g. a report of misuse). */
    public function close(Request $request, Campaign $campaign): RedirectResponse
    {
        $data = $request->validate(['note' => self::NOTE], [], ['note' => ui('fundraising.admin_note')]);
        $decided = $this->decide($campaign, 'active', fn () => ['status' => 'closed', 'ends_at' => now()], $request->user(), $data['note'] ?? null);

        return $this->done($decided, 'fundraising.admin_campaign_closed');
    }

    /**
     * @param  Builder<Campaign>  $query
     * @return array<int, array<string, mixed>>
     */
    public static function rows(Builder $query): array
    {
        return $query->with('mosque:id,slug,name,city,country_code,verified_at,logo_path')->get()
            ->map(fn (Campaign $c) => CampaignPresenter::card($c))->values()->all();
    }

    /**
     * Applies a decision once, under a row lock, if the campaign is still in
     * $from and $changes (given the locked row) returns the fields to set.
     *
     * @param  callable(Campaign): (array<string, mixed>|null)  $changes
     */
    private function decide(Campaign $campaign, string $from, callable $changes, User $admin, ?string $note): bool
    {
        $decided = DB::transaction(function () use ($campaign, $from, $changes, $admin, $note): bool {
            $locked = Campaign::query()->lockForUpdate()->find($campaign->id);
            if (! $locked || $locked->status !== $from) {
                return false;
            }
            $fields = $changes($locked);
            if ($fields === null) {
                return false;
            }
            $locked->forceFill([
                ...$fields,
                'reviewed_by' => $admin->id,
                'reviewed_at' => now(),
                'review_note' => $note !== null && trim($note) !== '' ? trim($note) : null,
            ])->save();
            $campaign->setRawAttributes($locked->getAttributes(), true);

            return true;
        });
        CampaignProgress::forget($campaign);

        return $decided;
    }

    private function done(bool $decided, string $message): RedirectResponse
    {
        Inertia::flash('toast', [
            'type' => $decided ? 'success' : 'error',
            'message' => ui($decided ? $message : 'fundraising.admin_campaign_already'),
        ]);

        return back(303);
    }
}
