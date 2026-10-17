<?php

namespace App\Http\Controllers\Display\Support;

use App\Models\Mosque;
use App\Models\MosqueDisplayMessage;
use Carbon\CarbonInterface;

/** A screen message as the settings page edits it (dates in the mosque's own time zone). */
class MessagePresenter
{
    public const LOCAL_FORMAT = 'Y-m-d\TH:i';

    /** @return list<array<string, mixed>> */
    public static function all(Mosque $mosque): array
    {
        return $mosque->displayMessages()
            ->orderBy('sort')
            ->orderBy('id')
            ->get()
            ->map(fn (MosqueDisplayMessage $message) => self::one($mosque, $message))
            ->values()
            ->all();
    }

    /** @return array<string, mixed> */
    public static function one(Mosque $mosque, MosqueDisplayMessage $message): array
    {
        return [
            'id' => $message->id,
            'body' => $message->body,
            'starts_at' => self::local($mosque, $message->starts_at),
            'ends_at' => self::local($mosque, $message->ends_at),
            'active' => (bool) $message->active,
            'state' => self::state($message),
        ];
    }

    /** "live", "scheduled", "ended" or "paused". */
    public static function state(MosqueDisplayMessage $message): string
    {
        return match (true) {
            ! $message->active => 'paused',
            $message->starts_at !== null && $message->starts_at->isFuture() => 'scheduled',
            $message->ends_at !== null && ! $message->ends_at->isFuture() => 'ended',
            default => 'live',
        };
    }

    private static function local(Mosque $mosque, ?CarbonInterface $at): ?string
    {
        return $at?->copy()->setTimezone($mosque->timezone)->format(self::LOCAL_FORMAT);
    }
}
