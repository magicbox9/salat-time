<?php

namespace App\Http\Controllers\Display\Support;

use App\Services\Display\DisplaySettings;

/** The choices a settings page offers, straight from config/display.php. */
class DisplayOptions
{
    /** @return array<string, mixed> */
    public static function all(string $scope): array
    {
        return [
            'themes' => config('display.themes'),
            'orientations' => config('display.orientations'),
            'languages' => config('display.languages'),
            'rotation_sources' => config('display.rotation_sources'),
            'adhan_modes' => config('display.adhan_modes'),
            'clocks' => config('display.clocks'),
            'ranges' => config('display.ranges'),
            'prayers' => DisplaySettings::PRAYERS,
            'keys' => DisplaySettings::keys($scope),
            'defaults' => DisplaySettings::merged([], $scope),
            'max_messages' => (int) config('display.max_messages', 30),
            'max_background_kb' => (int) config('display.max_background_kb'),
            'max_adhan_kb' => (int) config('display.max_adhan_kb'),
        ];
    }
}
