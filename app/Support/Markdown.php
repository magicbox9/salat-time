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
        return Str::markdown((string) $markdown, [
            'html_input' => 'strip',
            'allow_unsafe_links' => false,
            'max_nesting_level' => 20,
        ]);
    }

    /** Plain-text excerpt (for cards and meta descriptions). */
    public static function excerpt(?string $markdown, int $length = 220): string
    {
        $text = strip_tags(self::toHtml($markdown));

        return Str::limit(trim(preg_replace('/\s+/u', ' ', html_entity_decode($text))), $length);
    }
}
