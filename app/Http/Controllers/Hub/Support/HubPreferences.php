<?php

namespace App\Http\Controllers\Hub\Support;

use App\Models\User;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\Rule;

/**
 * How the hub shows the prayer times, stored per user in
 * users.preferences.home (guests keep the same object in localStorage).
 * Only the keys below are ever read or written.
 */
class HubPreferences
{
    public const STYLES = ['cards', 'timeline', 'arc', 'dial', 'minimal'];

    public const CLOCKS = ['24h', '12h'];

    public const ADHAN_MODES = ['off', 'sound', 'visual'];

    /** @var array<string, string|bool|null> */
    public const DEFAULTS = [
        'style' => 'cards',
        'show_iqama' => true,
        'show_seconds' => true,
        'clock' => '24h',
        'show_hijri' => true,
        'compact' => false,
        'adhan' => 'visual',
        'adhan_id' => null,
        'muted' => false,
    ];

    /** @return array<string, list<mixed>> */
    public static function rules(): array
    {
        return [
            'style' => ['sometimes', 'string', Rule::in(self::STYLES)],
            'show_iqama' => ['sometimes', 'boolean:strict'],
            'show_seconds' => ['sometimes', 'boolean:strict'],
            'clock' => ['sometimes', 'string', Rule::in(self::CLOCKS)],
            'show_hijri' => ['sometimes', 'boolean:strict'],
            'compact' => ['sometimes', 'boolean:strict'],
            'adhan' => ['sometimes', 'string', Rule::in(self::ADHAN_MODES)],
            // An id from GET /adhan/catalog.json (checked again when played).
            'adhan_id' => ['sometimes', 'nullable', 'string', 'max:64', 'regex:/^[A-Za-z0-9_.:-]+$/'],
            'muted' => ['sometimes', 'boolean:strict'],
        ];
    }

    /**
     * The user's choices over the defaults; unknown keys and values that are
     * no longer valid are ignored.
     *
     * @return array<string, string|bool|null>
     */
    public static function of(User $user): array
    {
        $all = $user->getAttribute('preferences');
        $stored = is_array($all) && is_array($all['home'] ?? null) ? $all['home'] : [];

        return [...self::DEFAULTS, ...self::sanitize($stored)];
    }

    /**
     * @param  array<string, mixed>  $values
     * @return array<string, string|bool|null>
     */
    public static function sanitize(array $values): array
    {
        $clean = [];
        foreach ($values as $key => $value) {
            $valid = match ($key) {
                'style' => in_array($value, self::STYLES, true),
                'clock' => in_array($value, self::CLOCKS, true),
                'adhan' => in_array($value, self::ADHAN_MODES, true),
                'adhan_id' => $value === null || (is_string($value) && preg_match('/^[A-Za-z0-9_.:-]{1,64}$/', $value) === 1),
                'show_iqama', 'show_seconds', 'show_hijri', 'compact', 'muted' => is_bool($value),
                default => false,
            };
            if ($valid) {
                $clean[$key] = $value;
            }
        }

        return $clean;
    }

    /**
     * Merges validated values into users.preferences.home in one statement,
     * so a concurrent change to another section (or another key) is kept.
     *
     * @param  array<string, mixed>  $values  validated input
     * @return array<string, string|bool|null>
     */
    public static function merge(User $user, array $values): array
    {
        $changes = self::sanitize($values);
        if ($changes !== []) {
            // A column holding no object (SQL NULL, JSON null, or the "[]" an
            // empty PHP array is stored as) starts from {}: jsonb_set cannot
            // set a key inside an array or a scalar.
            DB::update(
                "UPDATE users SET preferences = jsonb_set(
                    CASE WHEN jsonb_typeof(preferences) = 'object' THEN preferences ELSE '{}'::jsonb END, '{home}',
                    CASE WHEN jsonb_typeof(preferences -> 'home') = 'object' THEN preferences -> 'home' ELSE '{}'::jsonb END || ?::jsonb),
                    updated_at = ? WHERE id = ?",
                [json_encode($changes, JSON_THROW_ON_ERROR), now(), $user->id],
            );
            $user->refresh();
        }

        return self::of($user);
    }
}
