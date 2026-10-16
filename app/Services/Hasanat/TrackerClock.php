<?php

namespace App\Services\Hasanat;

use App\Models\Mosque;
use App\Models\User;
use Carbon\CarbonImmutable;

/**
 * "Today" for one person's tracker. The day follows their own mosque's time
 * zone; without a mosque, the time zone their device reports; otherwise the
 * app's default.
 */
final class TrackerClock
{
    public function __construct(
        public readonly string $timezone,
        public readonly CarbonImmutable $now,
        public readonly string $source,
        public readonly ?Mosque $mosque,
    ) {}

    public static function for(User $user, ?string $deviceTimezone = null): self
    {
        $mosque = self::primaryMosque($user);
        [$timezone, $source] = match (true) {
            $mosque !== null && self::validTimezone($mosque->timezone) => [$mosque->timezone, 'mosque'],
            self::validTimezone($deviceTimezone) => [(string) $deviceTimezone, 'device'],
            default => [(string) config('app.timezone', 'UTC'), 'default'],
        };

        return new self($timezone, CarbonImmutable::now($timezone), $source, $mosque);
    }

    /** The mosque the person marked as their own (primary favourite). */
    public static function primaryMosque(User $user): ?Mosque
    {
        /** @var Mosque|null $mosque */
        $mosque = $user->favoriteMosques()->wherePivot('is_primary', true)->first();

        return $mosque;
    }

    public static function validTimezone(?string $timezone): bool
    {
        return is_string($timezone) && $timezone !== ''
            // Browsers may report legacy aliases (e.g. Asia/Calcutta): accept them too.
            && in_array($timezone, \DateTimeZone::listIdentifiers(\DateTimeZone::ALL_WITH_BC), true);
    }

    public function today(): CarbonImmutable
    {
        return $this->now->startOfDay();
    }

    public function todayString(): string
    {
        return $this->now->toDateString();
    }

    /** The oldest date that can still be logged or changed. */
    public function oldestEditable(): CarbonImmutable
    {
        return $this->today()->subDays((int) config('hasanat.edit_window_days', 7));
    }

    public function isEditable(string $date): bool
    {
        return $date <= $this->todayString() && $date >= $this->oldestEditable()->toDateString();
    }

    /** Minutes after midnight, now, in this clock's time zone. */
    public function minutesNow(): int
    {
        return $this->now->hour * 60 + $this->now->minute;
    }
}
