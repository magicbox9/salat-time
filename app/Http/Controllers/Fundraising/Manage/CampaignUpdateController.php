<?php

namespace App\Http\Controllers\Fundraising\Manage;

use App\Http\Controllers\Controller;
use App\Http\Controllers\MosquePage\Support\PlainText;
use App\Models\Campaign;
use App\Models\CampaignUpdate;
use App\Models\Mosque;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Inertia\Inertia;

/** News on a campaign's page ("the roof is done"), written by the mosque in Markdown. */
class CampaignUpdateController extends Controller
{
    public function store(Request $request, Mosque $mosque, Campaign $campaign): RedirectResponse
    {
        $data = $request->validate([
            'title' => ['required', 'string', PlainText::RULE, 'min:3', 'max:160'],
            'body' => ['required', 'string', PlainText::RULE, 'min:3', 'max:10000'],
        ], [], [
            'title' => ui('fundraising.field_update_title'),
            'body' => ui('fundraising.field_update_body'),
        ]);

        CampaignUpdate::query()->create([
            'campaign_id' => $campaign->id,
            'author_id' => $request->user()->id,
            'title' => trim($data['title']),
            'body' => trim($data['body']),
        ]);
        Inertia::flash('toast', ['type' => 'success', 'message' => ui('fundraising.update_published')]);

        return to_route('manage.campaigns.show', [$mosque, $campaign]);
    }

    public function destroy(Mosque $mosque, Campaign $campaign, CampaignUpdate $update): RedirectResponse
    {
        $update->delete();
        Inertia::flash('toast', ['type' => 'success', 'message' => ui('fundraising.update_deleted')]);

        return to_route('manage.campaigns.show', [$mosque, $campaign]);
    }
}
