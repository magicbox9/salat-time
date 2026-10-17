<?php

namespace App\Http\Controllers\MosquePage\Support;

/**
 * The colour a mosque gives its site. Only "#rrggbb" values are kept; text
 * drawn on the colour is white or near-black, whichever reads better (WCAG
 * contrast), so any colour stays legible.
 */
final class AccentColor
{
    /** Curated colours offered to managers (from the Mac app's accents). */
    public const PALETTE = [
        '#0f6b56', '#166534', '#128585', '#1459b8', '#3f3d9e',
        '#66228c', '#b82b2b', '#d16b17', '#a37a33', '#1f2a2e',
    ];

    public const PATTERN = '/^#[0-9a-fA-F]{6}$/';

    private const LIGHT_TEXT = '#ffffff';

    private const DARK_TEXT = '#0b1a17';

    public static function normalize(mixed $value): ?string
    {
        return is_string($value) && preg_match(self::PATTERN, $value) ? strtolower($value) : null;
    }

    /** @return array{color: string, foreground: string, ink: string}|null */
    public static function present(mixed $value): ?array
    {
        $color = self::normalize($value);

        return $color === null ? null : [
            'color' => $color,
            'foreground' => self::foreground($color),
            'ink' => self::ink($color),
        ];
    }

    /**
     * The colour for text and icons drawn in the accent on the light theme's
     * white cards: the accent itself, or darkened just enough to read (WCAG
     * 4.5:1), so a pale custom colour never leaves text unreadable.
     */
    public static function ink(string $color): string
    {
        [$r, $g, $b] = array_map('hexdec', str_split(ltrim($color, '#'), 2));
        for ($step = 0; $step <= 20; $step++) {
            $keep = 1 - $step * 0.05;
            $candidate = sprintf('#%02x%02x%02x', (int) round($r * $keep), (int) round($g * $keep), (int) round($b * $keep));
            if (self::contrast($candidate, self::LIGHT_TEXT) >= 4.5) {
                return $candidate;
            }
        }

        return self::DARK_TEXT;
    }

    public static function foreground(string $color): string
    {
        return self::contrast($color, self::LIGHT_TEXT) >= self::contrast($color, self::DARK_TEXT)
            ? self::LIGHT_TEXT
            : self::DARK_TEXT;
    }

    public static function contrast(string $a, string $b): float
    {
        [$light, $dark] = [self::luminance($a), self::luminance($b)];
        if ($light < $dark) {
            [$light, $dark] = [$dark, $light];
        }

        return ($light + 0.05) / ($dark + 0.05);
    }

    private static function luminance(string $hex): float
    {
        $channels = array_map(function (string $pair): float {
            $c = hexdec($pair) / 255;

            return $c <= 0.03928 ? $c / 12.92 : (($c + 0.055) / 1.055) ** 2.4;
        }, str_split(ltrim($hex, '#'), 2));

        return 0.2126 * $channels[0] + 0.7152 * $channels[1] + 0.0722 * $channels[2];
    }
}
