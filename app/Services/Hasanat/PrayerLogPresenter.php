<?php

namespace App\Services\Hasanat;

use App\Models\PrayerLog;
use Carbon\CarbonImmutable;
use Carbon\CarbonInterface;

/** The JSON shape of one tracker log, shared by the web page and the phone API. */
class PrayerLogPresenter
{
    public function __construct(private readonly HasanatCalculator $calculator) {}

    /** The log's day as Y-m-d (prayer_date is cast to a date). */
    public static function dateOf(PrayerLog $log): string
    {
        /** @var CarbonInterface $date */
        $date = $log->prayer_date;

        return $date->toDateString();
    }

    /** @return array<string, mixed> */
    public function present(PrayerLog $log): array
    {
        // Every part but the streak is recomputed from the row; the streak is what remains.
        $parts = $this->calculator->breakdownForLog($log);
        $parts['streak'] = max(0, (int) $log->hasanat - $parts['total']);
        $parts['total'] = (int) $log->hasanat;

        return [
            'id' => $log->id,
            'date' => self::dateOf($log),
            'prayer' => $log->prayer,
            'status' => $log->status,
            'place' => $log->place,
            'mosque_id' => $log->mosque_id,
            'in_congregation' => (bool) $log->in_congregation,
            'source' => $log->source,
            'prayed_at' => $log->prayed_at ? CarbonImmutable::parse($log->prayed_at)->toIso8601String() : null,
            'metrics' => $log->metrics ?: null,
            'hasanat' => (int) $log->hasanat,
            'breakdown' => $parts,
            'updated_at' => $log->updated_at?->toIso8601String(),
        ];
    }
}
