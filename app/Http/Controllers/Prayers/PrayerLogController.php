<?php

namespace App\Http\Controllers\Prayers;

use App\Http\Controllers\Controller;
use App\Models\PrayerLog;
use App\Services\Hasanat\PrayerLogPresenter;
use App\Services\Hasanat\PrayerTracker;
use App\Services\Hasanat\TrackerClock;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Inertia\Inertia;

/** Web check-in: log a prayer (create or change) and undo it. */
class PrayerLogController extends Controller
{
    public function store(Request $request, PrayerTracker $tracker): RedirectResponse
    {
        $data = $request->validate(PrayerTracker::rules());
        $user = $request->user();
        [$log] = $tracker->record($user, $data, TrackerClock::for($user, $data['tz'] ?? null));

        Inertia::flash('toast', [
            'type' => 'success',
            'message' => $log->status === 'missed'
                ? ui('prayers.toast_saved_missed')
                : ui('prayers.toast_saved', ['points' => $log->hasanat]),
        ]);

        return back();
    }

    public function destroy(Request $request, PrayerLog $log, PrayerTracker $tracker): RedirectResponse
    {
        $user = $request->user();
        abort_unless((int) $log->user_id === (int) $user->id, 403);

        $data = $request->validate(['tz' => ['nullable', 'string', 'max:64']]);
        $clock = TrackerClock::for($user, $data['tz'] ?? null);
        if (! $clock->isEditable(PrayerLogPresenter::dateOf($log))) {
            Inertia::flash('toast', [
                'type' => 'error',
                'message' => ui('prayers.error_too_old', ['days' => config('hasanat.edit_window_days')]),
            ]);

            return back();
        }

        $tracker->remove($log);
        Inertia::flash('toast', ['type' => 'info', 'message' => ui('prayers.toast_removed')]);

        return back();
    }
}
