<?php

namespace App\Http\Controllers\Display;

use App\Http\Controllers\Controller;
use App\Models\Mosque;
use App\Models\MosqueDisplaySetting;
use App\Models\User;
use App\Services\Display\DisplayMediaStore;
use App\Services\Display\DisplayPayload;
use App\Services\Display\DisplaySettings;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Inertia\Inertia;
use Throwable;

/** The screen's background picture and the mosque's own adhan recording (upload / remove). */
class DisplayMediaController extends Controller
{
    public function storeBackground(Request $request, Mosque $mosque, DisplayMediaStore $store): RedirectResponse
    {
        $request->validate([
            'background' => ['required', 'file', 'image', 'mimes:jpg,jpeg,png,webp', 'max:'.config('display.max_background_kb'), 'dimensions:min_width=320,min_height=320,max_width=12000,max_height=12000'],
        ]);

        return $this->replace($request, $mosque, $store, 'background_path', fn () => $store->storeBackground($mosque, $request->file('background')));
    }

    public function destroyBackground(Request $request, Mosque $mosque, DisplayMediaStore $store): RedirectResponse
    {
        return $this->replace($request, $mosque, $store, 'background_path', fn () => null);
    }

    public function storeAdhan(Request $request, Mosque $mosque, DisplayMediaStore $store): RedirectResponse
    {
        $request->validate([
            'adhan' => ['required', 'file', 'mimes:mp3', 'mimetypes:audio/mpeg,audio/mp3,audio/mpeg3,audio/x-mpeg-3', 'max:'.config('display.max_adhan_kb')],
        ]);

        return $this->replace($request, $mosque, $store, 'adhan_audio_path', fn () => $store->storeAdhan($mosque, $request->file('adhan')));
    }

    public function destroyAdhan(Request $request, Mosque $mosque, DisplayMediaStore $store): RedirectResponse
    {
        return $this->replace($request, $mosque, $store, 'adhan_audio_path', fn () => null);
    }

    /** Stores the new file (or none), saves its path, then deletes the old one. */
    private function replace(Request $request, Mosque $mosque, DisplayMediaStore $store, string $column, callable $make): RedirectResponse
    {
        /** @var User $user */
        $user = $request->user();
        $row = MosqueDisplaySetting::query()->firstOrNew(['mosque_id' => $mosque->id]);
        if (! $row->exists) {
            $row->settings = DisplaySettings::merged([], DisplaySettings::MOSQUE);
        }
        $old = $row->getAttribute($column);
        $new = $make();

        try {
            $row->forceFill([$column => $new, 'updated_by' => $user->id])->save();
        } catch (Throwable $e) {
            $store->delete($mosque, $new);

            throw $e;
        }
        if ($old && $old !== $new) {
            $store->delete($mosque, $old);
        }
        DisplayPayload::forget($mosque);

        $message = $new === null ? 'display.removed' : 'display.uploaded';

        return Inertia::flash('toast', ['type' => 'success', 'message' => ui($message)])->back();
    }
}
