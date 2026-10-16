<?php

namespace App\Http\Controllers\Quran;

use App\Http\Controllers\Controller;
use App\Models\QuranBookmark;
use App\Models\User;
use App\Services\Content\QuranCorpus;
use Closure;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Gate;
use Inertia\Inertia;

/** A signed-in reader's bookmarks: one per ayah, optionally with a note. */
class QuranBookmarkController extends Controller
{
    public function store(Request $request, QuranCorpus $corpus): RedirectResponse|JsonResponse
    {
        $data = $request->validate([
            'surah' => ['required', 'integer', 'between:1,'.QuranCorpus::SURAH_COUNT],
            'ayah' => ['required', 'integer', 'min:1', function (string $attribute, mixed $value, Closure $fail) use ($request, $corpus) {
                $count = $corpus->ayahCount((int) $request->input('surah'));
                if ($count > 0 && (int) $value > $count) {
                    $fail(ui('quran.ayah_out_of_range', ['count' => $count]));
                }
            }],
            'note' => ['nullable', 'string', 'max:500'],
        ]);

        /** @var User $user */
        $user = $request->user();
        $note = $request->exists('note') ? ['note' => $data['note'] ?? null] : [];
        // firstOrCreate falls back to createOrFirst, so a double click cannot
        // trip the (user, surah, ayah) unique index.
        $bookmark = QuranBookmark::query()->firstOrCreate(
            ['user_id' => $user->id, 'surah' => (int) $data['surah'], 'ayah' => (int) $data['ayah']],
            $note,
        );
        if (! $bookmark->wasRecentlyCreated) {
            // Re-bookmarking from the reader keeps an existing note; the
            // timestamp still moves so "continue reading" points here.
            $bookmark->fill($note);
            $bookmark->isDirty() ? $bookmark->save() : $bookmark->touch();
        }

        if ($request->expectsJson() && ! $request->header('X-Inertia')) {
            return response()->json(['id' => $bookmark->id, 'surah' => $bookmark->surah, 'ayah' => $bookmark->ayah, 'note' => $bookmark->note]);
        }

        Inertia::flash('toast', ['type' => 'success', 'message' => ui('quran.bookmark_saved')]);

        return back();
    }

    public function destroy(Request $request, QuranBookmark $bookmark): RedirectResponse|JsonResponse
    {
        // Ownership comes from the stored row, never from the request.
        Gate::allowIf(fn (User $user) => (int) $user->id === (int) $bookmark->user_id);

        $bookmark->delete();

        if ($request->expectsJson() && ! $request->header('X-Inertia')) {
            return response()->json(['deleted' => true]);
        }

        Inertia::flash('toast', ['type' => 'success', 'message' => ui('quran.bookmark_removed')]);

        return back();
    }
}
