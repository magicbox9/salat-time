<?php

namespace App\Services\Display;

use App\Support\Ui;

/**
 * The words drawn on the screen itself, in every language a screen may show
 * (a mosque often shows Arabic with French or English under it, whatever the
 * language of the person who opened the page). Taken from the
 * lang/{locale}/display.json "screen_*" keys and the prayer names of site.json.
 */
class ScreenLabels
{
    private const PRAYERS = ['fajr', 'shuruq', 'dhuhr', 'asr', 'maghrib', 'isha', 'jumua'];

    /** @return array<string, array<string, string>> */
    public static function all(): array
    {
        $labels = [];
        foreach ((array) config('display.languages') as $locale) {
            $labels[$locale] = self::for($locale);
        }

        return $labels;
    }

    /** @return array<string, string> */
    public static function for(string $locale): array
    {
        $strings = Ui::strings($locale);
        $labels = [];
        foreach ($strings as $key => $value) {
            if (str_starts_with($key, 'display.screen_')) {
                $labels[substr($key, strlen('display.screen_'))] = $value;
            }
        }
        foreach (self::PRAYERS as $prayer) {
            $labels["prayer_$prayer"] = $strings["site.prayer_$prayer"] ?? ucfirst($prayer);
        }

        return $labels;
    }
}
