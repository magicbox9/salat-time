<?php

namespace App\Support;

use Illuminate\Support\Str;

/**
 * Markdown written by mosque managers (pages, khutbah texts, campaign stories)
 * turned into safe HTML: raw HTML is stripped and javascript:/data: links are
 * refused. Pages show it with <MarkdownContent html={…} /> only.
 */
class Markdown
{
    public static function toHtml(?string $markdown): string
    {
        $html = Str::markdown((string) $markdown, [
            'html_input' => 'strip',
            'allow_unsafe_links' => false,
            'max_nesting_level' => 20,
        ]);

        return self::localImagesOnly($html);
    }

    /**
     * Images from other sites would let them see every visitor (tracking
     * pixels): only images stored on this site are shown; others become links.
     */
    private static function localImagesOnly(string $html): string
    {
        if (! str_contains($html, '<img')) {
            return $html;
        }

        return (string) preg_replace_callback('/<img\b[^>]*>/i', function (array $m): string {
            $src = preg_match('/\bsrc="([^"]*)"/i', $m[0], $s) ? html_entity_decode($s[1]) : '';
            $alt = preg_match('/\balt="([^"]*)"/i', $m[0], $a) ? $a[1] : '';
            if (self::isLocal($src)) {
                return $m[0];
            }
            $label = $alt !== '' ? $alt : e(parse_url($src, PHP_URL_HOST) ?: $src);

            return $src === '' ? '' : '<a href="'.e($src).'" rel="nofollow noopener noreferrer" target="_blank">'.$label.'</a>';
        }, $html);
    }

    private static function isLocal(string $src): bool
    {
        if (str_starts_with($src, '/storage/')) {
            return ! str_starts_with($src, '//');
        }
        $host = parse_url($src, PHP_URL_HOST);
        $scheme = parse_url($src, PHP_URL_SCHEME);

        return $host !== null && in_array($scheme, ['http', 'https'], true)
            && strcasecmp($host, (string) parse_url((string) config('app.url'), PHP_URL_HOST)) === 0
            && str_starts_with((string) parse_url($src, PHP_URL_PATH), '/storage/');
    }

    /** Plain-text excerpt (for cards and meta descriptions). */
    public static function excerpt(?string $markdown, int $length = 220): string
    {
        $text = strip_tags(self::toHtml($markdown));

        return Str::limit(trim(preg_replace('/\s+/u', ' ', html_entity_decode($text))), $length);
    }
}
