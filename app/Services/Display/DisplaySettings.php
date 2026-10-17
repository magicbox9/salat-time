<?php

namespace App\Services\Display;

use App\Models\Mosque;
use App\Models\MosqueDisplaySetting;
use App\Models\User;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\Rule;

/**
 * The display's settings: one list of known keys (config/display.php
 * `defaults`), validated strictly and merged over the defaults. A mosque's
 * choices live in mosque_display_settings.settings, a person's in
 * users.preferences.display; anything else ever stored there is ignored.
 */
class DisplaySettings
{
    public const MOSQUE = 'mosque';

    public const PERSONAL = 'personal';

    public const PRAYERS = ['fajr', 'dhuhr', 'asr', 'maghrib', 'isha', 'jumua'];

    private const ID = '/^[A-Za-z0-9_.:-]{1,64}$/';

    private const COLOR = '/^#[0-9a-fA-F]{6}$/';

    private const TIME = '/^([01]\d|2[0-3]):[0-5]\d$/';

    /** Marks a value sanitize() drops. */
    private const INVALID = "\0invalid";

    /** @return array<string, mixed> */
    public static function defaults(): array
    {
        return config('display.defaults');
    }

    /** @return list<string> */
    public static function keys(string $scope): array
    {
        $keys = array_keys(self::defaults());

        // A mosque screen is muted from its own on-screen controls, per device.
        return $scope === self::MOSQUE ? array_values(array_diff($keys, ['muted'])) : $keys;
    }

    /**
     * Validation rules for a partial update (every key is optional).
     *
     * @return array<string, list<mixed>>
     */
    public static function rules(string $scope): array
    {
        $range = fn (string $key) => 'between:'.implode(',', config("display.ranges.$key"));
        $rules = [
            'theme' => ['sometimes', 'string', Rule::in(config('display.themes'))],
            'orientation' => ['sometimes', 'string', Rule::in(config('display.orientations'))],
            'accent_color' => ['sometimes', 'nullable', 'string', 'regex:'.self::COLOR],
            'languages' => ['sometimes', 'array', 'min:1', 'max:2'],
            'languages.*' => ['string', 'distinct', Rule::in(config('display.languages'))],
            'clock' => ['sometimes', 'string', Rule::in(config('display.clocks'))],
            'show_seconds' => ['sometimes', 'boolean:strict'],
            'show_iqama' => ['sometimes', 'boolean:strict'],
            'show_shuruq' => ['sometimes', 'boolean:strict'],
            'show_jumua' => ['sometimes', 'boolean:strict'],
            'show_hijri' => ['sometimes', 'boolean:strict'],
            'hijri_adjust' => ['sometimes', 'integer', $range('hijri_adjust')],
            'approaching_minutes' => ['sometimes', 'integer', $range('approaching_minutes')],
            'adhan_minutes' => ['sometimes', 'integer', $range('adhan_minutes')],
            'iqama_seconds' => ['sometimes', 'integer', $range('iqama_seconds')],
            'blackout_minutes' => ['sometimes', 'array'],
            'after_adhkar' => ['sometimes', 'boolean:strict'],
            'after_adhkar_minutes' => ['sometimes', 'integer', $range('after_adhkar_minutes')],
            'rotation' => ['sometimes', 'array', 'max:'.count(config('display.rotation_sources'))],
            'rotation.*' => ['string', 'distinct', Rule::in(config('display.rotation_sources'))],
            'rotation_seconds' => ['sometimes', 'integer', $range('rotation_seconds')],
            'adhan_mode' => ['sometimes', 'string', Rule::in(config('display.adhan_modes'))],
            // Ids from GET /adhan/catalog.json (resolved again by the screen).
            'adhan_id' => ['sometimes', 'nullable', 'string', 'regex:'.self::ID],
            'fajr_adhan_id' => ['sometimes', 'nullable', 'string', 'regex:'.self::ID],
            'volume' => ['sometimes', 'integer', $range('volume')],
            'muted' => ['sometimes', 'boolean:strict'],
            'night_dim' => ['sometimes', 'boolean:strict'],
            'night_from' => ['sometimes', 'string', 'regex:'.self::TIME],
            'night_to' => ['sometimes', 'string', 'regex:'.self::TIME],
        ];
        foreach (self::PRAYERS as $prayer) {
            $rules["blackout_minutes.$prayer"] = ['sometimes', 'integer', $range('blackout_minutes')];
        }

        $allowed = self::keys($scope);

        return array_filter($rules, fn (string $key) => in_array(explode('.', $key)[0], $allowed, true), ARRAY_FILTER_USE_KEY);
    }

    /**
     * Only known keys with valid values; everything else is dropped.
     *
     * @param  array<string, mixed>  $values
     * @return array<string, mixed>
     */
    public static function sanitize(array $values, string $scope): array
    {
        $clean = [];
        foreach (array_intersect_key($values, array_flip(self::keys($scope))) as $key => $value) {
            $value = self::clean($key, $value);
            if ($value !== self::INVALID) {
                $clean[$key] = $value;
            }
        }

        return $clean;
    }

    /**
     * The defaults with these choices over them.
     *
     * @param  array<string, mixed>  $stored
     * @return array<string, mixed>
     */
    public static function merged(array $stored, string $scope): array
    {
        $defaults = array_intersect_key(self::defaults(), array_flip(self::keys($scope)));
        $clean = self::sanitize($stored, $scope);
        $merged = [...$defaults, ...$clean];
        $merged['blackout_minutes'] = [...$defaults['blackout_minutes'], ...($clean['blackout_minutes'] ?? [])];

        return $merged;
    }

    /** @return array<string, mixed> */
    public static function forMosque(Mosque $mosque): array
    {
        $row = $mosque->relationLoaded('displaySetting') ? $mosque->displaySetting : $mosque->displaySetting()->first();

        return self::merged(is_array($row?->settings) ? $row->settings : [], self::MOSQUE);
    }

    /** @return array<string, mixed>|null The person's own choices, or null before they saved any. */
    public static function forUser(User $user): ?array
    {
        $all = $user->getAttribute('preferences');
        $stored = is_array($all) && is_array($all['display'] ?? null) ? $all['display'] : null;

        return $stored === null ? null : self::merged($stored, self::PERSONAL);
    }

    /**
     * Saves validated changes over the mosque's current settings.
     *
     * @param  array<string, mixed>  $values
     * @return array<string, mixed>
     */
    public static function saveForMosque(Mosque $mosque, array $values, User $by): array
    {
        $settings = self::merged(self::overlay(self::forMosque($mosque), self::sanitize($values, self::MOSQUE)), self::MOSQUE);
        $row = MosqueDisplaySetting::query()->firstOrNew(['mosque_id' => $mosque->id]);
        $row->forceFill(['settings' => $settings, 'updated_by' => $by->id])->save();
        $mosque->setRelation('displaySetting', $row);

        return $settings;
    }

    /**
     * Saves validated changes into users.preferences.display in one
     * statement, so other sections of the preferences are kept.
     *
     * @param  array<string, mixed>  $values
     * @return array<string, mixed>
     */
    public static function saveForUser(User $user, array $values): array
    {
        $settings = self::merged(self::overlay(self::forUser($user) ?? [], self::sanitize($values, self::PERSONAL)), self::PERSONAL);
        DB::update(
            "UPDATE users SET preferences = jsonb_set(
                CASE WHEN jsonb_typeof(preferences) = 'object' THEN preferences ELSE '{}'::jsonb END,
                '{display}', ?::jsonb), updated_at = ? WHERE id = ?",
            [json_encode($settings, JSON_THROW_ON_ERROR), now(), $user->id],
        );
        $user->refresh();

        return $settings;
    }

    /**
     * Changes over current settings; the per-prayer blackout minutes merge key by key.
     *
     * @param  array<string, mixed>  $current
     * @param  array<string, mixed>  $changes
     * @return array<string, mixed>
     */
    private static function overlay(array $current, array $changes): array
    {
        $merged = [...$current, ...$changes];
        if (isset($changes['blackout_minutes'])) {
            $merged['blackout_minutes'] = [...($current['blackout_minutes'] ?? []), ...$changes['blackout_minutes']];
        }

        return $merged;
    }

    private static function clean(string $key, mixed $value): mixed
    {
        $in = fn (string $list) => is_string($value) && in_array($value, config("display.$list"), true) ? $value : self::INVALID;

        return match ($key) {
            'theme' => $in('themes'),
            'orientation' => $in('orientations'),
            'clock' => $in('clocks'),
            'adhan_mode' => $in('adhan_modes'),
            'accent_color' => self::color($value),
            'adhan_id', 'fajr_adhan_id' => $value === null || (is_string($value) && preg_match(self::ID, $value)) ? $value : self::INVALID,
            'night_from', 'night_to' => is_string($value) && preg_match(self::TIME, $value) ? $value : self::INVALID,
            'languages' => self::subset($value, config('display.languages'), 1, 2),
            'rotation' => self::subset($value, config('display.rotation_sources'), 0, PHP_INT_MAX),
            'blackout_minutes' => self::blackout($value),
            'show_seconds', 'show_iqama', 'show_shuruq', 'show_jumua', 'show_hijri',
            'after_adhkar', 'muted', 'night_dim' => is_bool($value) ? $value : self::INVALID,
            default => self::integer($value, config("display.ranges.$key")),
        };
    }

    private static function color(mixed $value): mixed
    {
        if ($value === null) {
            return null;
        }

        return is_string($value) && preg_match(self::COLOR, $value) ? strtolower($value) : self::INVALID;
    }

    /** @param  list<int>|null  $range */
    private static function integer(mixed $value, ?array $range): mixed
    {
        if ($range === null || ! (is_int($value) || (is_string($value) && preg_match('/^-?\d{1,4}$/', $value)))) {
            return self::INVALID;
        }
        $number = (int) $value;

        return $number >= $range[0] && $number <= $range[1] ? $number : self::INVALID;
    }

    /** @param  list<string>  $allowed */
    private static function subset(mixed $value, array $allowed, int $min, int $max): mixed
    {
        if (! is_array($value) || ! array_is_list($value)) {
            return self::INVALID;
        }
        $items = array_values(array_unique(array_filter($value, fn ($item) => is_string($item) && in_array($item, $allowed, true))));

        return count($items) >= $min && count($items) <= $max ? $items : self::INVALID;
    }

    private static function blackout(mixed $value): mixed
    {
        if (! is_array($value)) {
            return self::INVALID;
        }
        $clean = [];
        foreach (self::PRAYERS as $prayer) {
            if (array_key_exists($prayer, $value)) {
                $minutes = self::integer($value[$prayer], config('display.ranges.blackout_minutes'));
                if ($minutes !== self::INVALID) {
                    $clean[$prayer] = $minutes;
                }
            }
        }

        return $clean;
    }
}
