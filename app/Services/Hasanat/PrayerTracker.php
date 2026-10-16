<?php

namespace App\Services\Hasanat;

use App\Models\PrayerLog;
use App\Models\User;
use App\Services\PrayerTimes\MosqueTimetable;
use Carbon\CarbonImmutable;
use Illuminate\Database\UniqueConstraintViolationException;
use Illuminate\Support\Arr;
use Illuminate\Support\Collection;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\Rule;
use Illuminate\Validation\ValidationException;

/**
 * Records prayers in the personal tracker (web check-in and phone apps) and
 * keeps every log's hasanat up to date, streak bonus included.
 */
class PrayerTracker
{
    public const METRIC_KEYS = ['rakaat', 'ruku', 'sujud', 'duration_seconds', 'stillness', 'started_at', 'ended_at'];

    /** ISO 8601 date-time with an explicit offset, e.g. 2026-03-10T13:05:00+01:00 or …T12:05:00.123Z. */
    public const ISO_DATETIME = 'regex:/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}(:\d{2}(\.\d{1,9})?)?(Z|[+-]\d{2}:?\d{2})$/';

    public function __construct(
        private readonly HasanatCalculator $calculator,
        private readonly MosqueTimetable $timetable,
    ) {}

    /**
     * Validation rules for a check-in. Phone apps also send their source and sensor metrics.
     *
     * @return array<string, mixed>
     */
    public static function rules(bool $fromPhone = false): array
    {
        $rules = [
            'prayer_date' => ['required', 'date_format:Y-m-d'],
            'prayer' => ['required', 'string', Rule::in(PrayerLog::PRAYERS)],
            'status' => ['required', 'string', Rule::in(PrayerLog::STATUSES)],
            'place' => ['nullable', 'string', Rule::in(PrayerLog::PLACES)],
            'mosque_id' => ['nullable', 'integer', 'exists:mosques,id'],
            'in_congregation' => ['nullable', 'boolean'],
            'tz' => ['nullable', 'string', 'max:64'],
        ];

        if ($fromPhone) {
            $rules += [
                'source' => ['required', 'string', Rule::in(['ios', 'android'])],
                'prayed_at' => ['nullable', 'string', self::ISO_DATETIME, 'date'],
                'metrics' => ['nullable', 'array'],
                'metrics.rakaat' => ['nullable', 'integer', 'between:1,20'],
                'metrics.ruku' => ['nullable', 'integer', 'between:0,40'],
                'metrics.sujud' => ['nullable', 'integer', 'between:0,80'],
                'metrics.duration_seconds' => ['nullable', 'integer', 'between:30,7200'],
                'metrics.stillness' => ['nullable', 'numeric', 'between:0,1'],
                'metrics.started_at' => ['nullable', 'string', self::ISO_DATETIME, 'date'],
                'metrics.ended_at' => ['nullable', 'string', self::ISO_DATETIME, 'date', 'after_or_equal:metrics.started_at'],
            ];
        }

        return $rules;
    }

    /**
     * Creates or updates the log for (date, prayer). Rejects future prayers and
     * dates outside the edit window.
     *
     * @param  array<string, mixed>  $data  validated input
     * @return array{0: PrayerLog, 1: bool} the log and whether it was created
     */
    public function record(User $user, array $data, TrackerClock $clock, string $source = 'web'): array
    {
        $date = (string) $data['prayer_date'];
        $prayer = (string) $data['prayer'];
        $this->assertLoggable($date, $prayer, $clock);

        $status = (string) $data['status'];
        $place = (string) ($data['place'] ?? 'home');
        $missed = $status === 'missed';
        $metrics = isset($data['metrics']) && is_array($data['metrics'])
            ? $this->normalizeMetrics($data['metrics'])
            : null;

        $values = [
            'status' => $status,
            'place' => $place,
            'mosque_id' => ! $missed && $place === 'mosque' ? ($data['mosque_id'] ?? $clock->mosque?->id) : null,
            'in_congregation' => ! $missed && (bool) ($data['in_congregation'] ?? false),
        ];

        $save = function () use ($user, $date, $prayer, $values, $data, $metrics, $missed, $clock, $source) {
            $this->lockTracker($user);
            $log = PrayerLog::query()->firstOrNew(['user_id' => $user->id, 'prayer_date' => $date, 'prayer' => $prayer]);
            $created = ! $log->exists;
            // Still at a mosque and none named (a web edit): keep the mosque already recorded.
            if (! $missed && $values['place'] === 'mosque' && ! isset($data['mosque_id']) && $log->place === 'mosque' && $log->mosque_id) {
                $values['mosque_id'] = $log->mosque_id;
            }
            $log->fill($values);
            // A web edit keeps the phone's sensor data and source; a phone check-in replaces them.
            if ($source !== 'web') {
                $log->fill(['source' => $source, 'metrics' => $metrics ?: null]);
            } elseif ($created || empty($log->metrics)) {
                $log->source = 'web';
            }
            $log->prayed_at = $missed ? null : $this->prayedAt($log, $data, $metrics, $date, $clock);
            $log->save();
            $this->rescore($user, CarbonImmutable::parse($date));

            return [$log->refresh(), $created];
        };

        try {
            return DB::transaction($save);
        } catch (UniqueConstraintViolationException) {
            // Two check-ins for the same prayer at once: the second one updates.
            return DB::transaction($save);
        }
    }

    /** Removes a log (undo) and rescores the days after it. */
    public function remove(PrayerLog $log): void
    {
        DB::transaction(function () use ($log) {
            /** @var User $user */
            $user = $log->user;
            $this->lockTracker($user);
            $date = CarbonImmutable::parse(PrayerLogPresenter::dateOf($log));
            $log->delete();
            $this->rescore($user, $date);
        });
    }

    /**
     * Recomputes hasanat from $from onwards. The streak bonus of a day depends
     * on the days before it, so earlier days (up to the cap) are read too.
     */
    public function rescore(User $user, CarbonImmutable $from): void
    {
        $cap = $this->calculator->maxStreakDays();
        $fromDate = $from->toDateString();
        /** @var Collection<int, PrayerLog> $logs */
        $logs = $user->prayerLogs()
            ->where('prayer_date', '>=', $from->subDays(max(1, $cap))->toDateString())
            ->get();
        /** @var Collection<string, Collection<int, PrayerLog>> $byDate */
        $byDate = $logs->groupBy(fn (PrayerLog $log) => PrayerLogPresenter::dateOf($log));
        $complete = $byDate->map(fn (Collection $day) => $this->isComplete($day));

        foreach ($byDate as $date => $dayLogs) {
            if ($date < $fromDate) {
                continue;
            }
            $streak = 0;
            $cursor = CarbonImmutable::parse($date);
            while ($streak < $cap && ($complete[$cursor->toDateString()] ?? false)) {
                $streak++;
                $cursor = $cursor->subDay();
            }
            foreach ($dayLogs as $log) {
                $points = $this->calculator->forLog($log, $streak);
                if ((int) $log->hasanat !== $points) {
                    $log->forceFill(['hasanat' => $points])->saveQuietly();
                }
            }
        }
    }

    /** @param  Collection<int, PrayerLog>  $day */
    public function isComplete(Collection $day): bool
    {
        $statuses = $this->calculator->streakStatuses();

        return $day->filter(fn (PrayerLog $log) => in_array($log->status, $statuses, true))
            ->pluck('prayer')->unique()->count() === count(PrayerLog::PRAYERS);
    }

    /**
     * Serializes one person's tracker writes. The streak bonus of a day depends
     * on all five of its prayers: two check-ins saved at the same moment (a
     * phone syncing its queue) would each rescore without seeing the other and
     * leave the day's bonus wrong. Must be called inside the transaction.
     */
    private function lockTracker(User $user): void
    {
        DB::table('users')->where('id', $user->id)->lockForUpdate()->value('id');
    }

    /**
     * Keeps the known sensor metrics only; times are stored as ISO 8601 in UTC
     * so every client reads them the same way.
     *
     * @param  array<mixed>  $input
     * @return array<string, mixed>
     */
    private function normalizeMetrics(array $input): array
    {
        $metrics = array_filter(Arr::only($input, self::METRIC_KEYS), fn ($v) => $v !== null);
        foreach (['started_at', 'ended_at'] as $key) {
            if (isset($metrics[$key])) {
                $metrics[$key] = CarbonImmutable::parse((string) $metrics[$key])->utc()->toIso8601String();
            }
        }

        return $metrics;
    }

    /** @throws ValidationException */
    private function assertLoggable(string $date, string $prayer, TrackerClock $clock): void
    {
        $days = (int) config('hasanat.edit_window_days', 7);
        if ($date > $clock->todayString()) {
            throw ValidationException::withMessages(['prayer_date' => ui('prayers.error_future')]);
        }
        if ($date < $clock->oldestEditable()->toDateString()) {
            throw ValidationException::withMessages(['prayer_date' => ui('prayers.error_too_old', ['days' => $days])]);
        }
        // Today, with the mosque's published times: the prayer's time must have come.
        if ($date === $clock->todayString() && $clock->mosque) {
            $start = $this->timetable->day($clock->mosque, $clock->now)['times'][$prayer] ?? null;
            $minutes = $start ? MosqueTimetable::minutes($start) : null;
            if ($minutes !== null && $clock->minutesNow() < $minutes) {
                throw ValidationException::withMessages(['prayer' => ui('prayers.error_not_yet')]);
            }
        }
    }

    /**
     * @param  array<string, mixed>  $data
     * @param  array<string, mixed>|null  $metrics
     */
    private function prayedAt(PrayerLog $log, array $data, ?array $metrics, string $date, TrackerClock $clock): ?CarbonImmutable
    {
        $given = $data['prayed_at'] ?? ($metrics['started_at'] ?? null);
        if ($given) {
            return CarbonImmutable::parse((string) $given)->utc();
        }
        if ($log->prayed_at) {
            return CarbonImmutable::parse($log->prayed_at);
        }

        return $date === $clock->todayString() ? $clock->now->utc() : null;
    }
}
