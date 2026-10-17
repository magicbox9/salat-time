<?php

namespace App\Http\Controllers\Display;

use App\Http\Controllers\Controller;
use App\Http\Controllers\Display\Support\MessagePresenter;
use App\Models\Mosque;
use App\Models\MosqueDisplayMessage;
use App\Services\Display\DisplayPayload;
use Carbon\CarbonImmutable;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;
use Inertia\Inertia;

/**
 * The short messages a mosque's screen rotates through: plain text (never
 * HTML), optionally shown only between a start and an end, in the order the
 * managers choose. Dates are typed in the mosque's own time zone.
 */
class DisplayMessageController extends Controller
{
    public function store(Request $request, Mosque $mosque): RedirectResponse
    {
        $values = $this->validated($request, $mosque);
        if ($mosque->displayMessages()->count() >= (int) config('display.max_messages', 30)) {
            throw ValidationException::withMessages(['body' => ui('display.messages_full')]);
        }

        $message = new MosqueDisplayMessage;
        $message->forceFill([
            ...$values,
            'mosque_id' => $mosque->id,
            'sort' => (int) $mosque->displayMessages()->max('sort') + 1,
        ])->save();

        return $this->done($mosque, 'display.message_added');
    }

    public function update(Request $request, Mosque $mosque, string $message): RedirectResponse
    {
        $record = $this->find($mosque, $message);
        // A paused message stays paused unless "active" is sent.
        $record->forceFill($this->validated($request, $mosque, (bool) $record->active))->save();

        return $this->done($mosque, 'display.message_saved');
    }

    public function destroy(Mosque $mosque, string $message): RedirectResponse
    {
        $this->find($mosque, $message)->delete();

        return $this->done($mosque, 'display.message_deleted');
    }

    public function reorder(Request $request, Mosque $mosque): RedirectResponse
    {
        $data = $request->validate([
            'ids' => ['required', 'array', 'max:'.config('display.max_messages', 30)],
            'ids.*' => ['integer', 'distinct', 'min:1'],
        ]);
        $ids = array_map('intval', $data['ids']);
        $owned = $mosque->displayMessages()->whereIn('id', $ids)->pluck('id')->all();
        // The whole list, each of this mosque's messages once (a part would leave two at one place).
        if (count($owned) !== count($ids) || count($ids) !== $mosque->displayMessages()->count()) {
            throw ValidationException::withMessages(['ids' => ui('display.messages_reorder_invalid')]);
        }

        DB::transaction(function () use ($mosque, $ids) {
            foreach ($ids as $position => $id) {
                $mosque->displayMessages()->whereKey($id)->update(['sort' => $position + 1]);
            }
        });

        return $this->done($mosque, 'display.messages_reordered');
    }

    /** @return array{body: string, starts_at: CarbonImmutable|null, ends_at: CarbonImmutable|null, active: bool} */
    private function validated(Request $request, Mosque $mosque, bool $active = true): array
    {
        $format = 'date_format:'.MessagePresenter::LOCAL_FORMAT;
        $data = $request->validate([
            'body' => ['required', 'string', 'max:500'],
            'starts_at' => ['nullable', 'string', $format],
            'ends_at' => ['nullable', 'string', $format],
            'active' => ['sometimes', 'boolean'],
        ]);
        // Plain text on one screen: no control characters, tidy spaces.
        $body = trim((string) preg_replace(['/[\x{0000}-\x{0008}\x{000B}-\x{001F}\x{007F}]/u', '/[ \t]+/u'], ['', ' '], $data['body']));
        if ($body === '') {
            throw ValidationException::withMessages(['body' => ui('display.message_empty')]);
        }
        $starts = $this->local($mosque, $data['starts_at'] ?? null);
        $ends = $this->local($mosque, $data['ends_at'] ?? null);
        if ($starts && $ends && $ends->lessThanOrEqualTo($starts)) {
            throw ValidationException::withMessages(['ends_at' => ui('display.message_end_before_start')]);
        }

        return ['body' => $body, 'starts_at' => $starts, 'ends_at' => $ends, 'active' => $request->boolean('active', $active)];
    }

    private function local(Mosque $mosque, ?string $value): ?CarbonImmutable
    {
        if ($value === null || $value === '') {
            return null;
        }

        return CarbonImmutable::createFromFormat(MessagePresenter::LOCAL_FORMAT, $value, $mosque->timezone)->utc();
    }

    private function find(Mosque $mosque, string $id): MosqueDisplayMessage
    {
        /** @var MosqueDisplayMessage */
        return $mosque->displayMessages()->whereKey((int) $id)->firstOrFail();
    }

    private function done(Mosque $mosque, string $message): RedirectResponse
    {
        DisplayPayload::forget($mosque);

        return Inertia::flash('toast', ['type' => 'success', 'message' => ui($message)])->back();
    }
}
