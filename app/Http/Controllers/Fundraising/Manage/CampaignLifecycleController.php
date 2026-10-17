<?php

namespace App\Http\Controllers\Fundraising\Manage;

use App\Http\Controllers\Controller;
use App\Models\Campaign;
use App\Models\Mosque;
use App\Notifications\CampaignSubmitted;
use App\Services\Fundraising\CampaignEligibility;
use App\Services\Fundraising\CampaignProgress;
use App\Services\Fundraising\FundraisingMail;
use App\Services\Fundraising\ModelDate;
use Illuminate\Http\RedirectResponse;
use Illuminate\Support\Facades\DB;
use Inertia\Inertia;

/**
 * A campaign goes to review (draft or rejected → pending) only when the
 * mosque is verified and every way of giving it allows is verified; the
 * mosque may close an open campaign at any time.
 */
class CampaignLifecycleController extends Controller
{
    public function submit(Mosque $mosque, Campaign $campaign, CampaignEligibility $eligibility, FundraisingMail $mail): RedirectResponse
    {
        $problems = $eligibility->submissionProblems($campaign, $mosque);
        if ($problems !== []) {
            Inertia::flash('toast', ['type' => 'error', 'message' => ui('fundraising.problem_'.$problems[0])]);

            return to_route('manage.campaigns.show', [$mosque, $campaign]);
        }

        $submitted = DB::transaction(function () use ($campaign): bool {
            $locked = Campaign::query()->lockForUpdate()->find($campaign->id);
            if (! $locked || ! in_array($locked->status, ['draft', 'rejected'], true)) {
                return false;
            }
            $locked->forceFill(['status' => 'pending', 'review_note' => null, 'reviewed_by' => null, 'reviewed_at' => null])->save();
            $campaign->setRawAttributes($locked->getAttributes(), true);

            return true;
        });

        if (! $submitted) {
            Inertia::flash('toast', ['type' => 'error', 'message' => ui('fundraising.campaign_not_submittable')]);

            return to_route('manage.campaigns.show', [$mosque, $campaign]);
        }

        $mail->toAdmins(new CampaignSubmitted($campaign));
        Inertia::flash('toast', ['type' => 'success', 'message' => ui('fundraising.campaign_submitted')]);

        return to_route('manage.campaigns.show', [$mosque, $campaign]);
    }

    /** Ends an open campaign: "completed" when the goal was reached, otherwise "closed". */
    public function close(Mosque $mosque, Campaign $campaign): RedirectResponse
    {
        $closed = DB::transaction(function () use ($campaign): bool {
            $locked = Campaign::query()->lockForUpdate()->find($campaign->id);
            if (! $locked || $locked->status !== 'active') {
                return false;
            }
            $locked->forceFill([
                'status' => $locked->raised_amount >= $locked->goal_amount ? 'completed' : 'closed',
                'ends_at' => ModelDate::of($locked, 'ends_at')?->isPast() ? ModelDate::of($locked, 'ends_at') : now(),
            ])->save();
            $campaign->setRawAttributes($locked->getAttributes(), true);

            return true;
        });

        CampaignProgress::forget($campaign);
        Inertia::flash('toast', [
            'type' => $closed ? 'success' : 'error',
            'message' => ui($closed ? 'fundraising.campaign_closed' : 'fundraising.campaign_not_open'),
        ]);

        return to_route('manage.campaigns.show', [$mosque, $campaign]);
    }
}
