<?php

namespace App\Support;

use Illuminate\Support\Facades\Cache;

/**
 * Interface strings for the React pages and for server messages (toasts).
 *
 * Each feature keeps its own files: lang/{locale}/{group}.json, a flat object.
 * Keys are used as "{group}.{key}" (e.g. "site.nav_quran"). English is the
 * fallback for any key a translation lacks.
 */
class Ui
{
    public const LOCALES = ['en' => 'English', 'fr' => 'Français', 'ar' => 'العربية'];

    public const RTL = ['ar'];

    /** @return array<string, string> */
    public static function strings(string $locale): array
    {
        $locale = array_key_exists($locale, self::LOCALES) ? $locale : 'en';
        $load = fn () => array_merge(self::load('en'), $locale === 'en' ? [] : self::load($locale));

        return app()->isProduction() ? Cache::rememberForever("ui-strings:$locale", $load) : $load();
    }

    public static function t(string $key, array $replace = [], ?string $locale = null): string
    {
        $text = self::strings($locale ?? app()->getLocale())[$key] ?? $key;
        foreach ($replace as $name => $value) {
            $text = str_replace('{'.$name.'}', (string) $value, $text);
        }

        return $text;
    }

    public static function direction(string $locale): string
    {
        return in_array($locale, self::RTL, true) ? 'rtl' : 'ltr';
    }

    /** @return array<string, string> */
    private static function load(string $locale): array
    {
        $strings = [];
        foreach (glob(lang_path("$locale/*.json")) ?: [] as $file) {
            $group = basename($file, '.json');
            foreach (json_decode((string) file_get_contents($file), true) ?: [] as $key => $value) {
                $strings["$group.$key"] = (string) $value;
            }
        }

        return $strings;
    }
}
