<?php

namespace App\Http\Controllers\MosquePage\Support;

/**
 * Khutbah recordings: YouTube and Vimeo links only, embedded through their
 * privacy-enhanced players (youtube-nocookie.com, Vimeo with "do not track").
 * Anything else is refused, so a post can never frame an arbitrary site.
 */
final class VideoEmbed
{
    private const YOUTUBE_HOSTS = ['youtube.com', 'www.youtube.com', 'm.youtube.com', 'music.youtube.com',
        'youtube-nocookie.com', 'www.youtube-nocookie.com'];

    private const VIMEO_HOSTS = ['vimeo.com', 'www.vimeo.com', 'player.vimeo.com'];

    private const YOUTUBE_ID = '/^[A-Za-z0-9_-]{11}$/';

    /**
     * @return array{provider: 'youtube'|'vimeo', id: string, url: string, embed_url: string}|null
     */
    public static function parse(?string $url): ?array
    {
        $url = trim((string) $url);
        if ($url === '' || strlen($url) > 500 || preg_match('/\s/', $url)) {
            return null;
        }

        $parts = parse_url($url);
        $scheme = strtolower((string) ($parts['scheme'] ?? ''));
        $host = strtolower((string) ($parts['host'] ?? ''));
        if (! in_array($scheme, ['http', 'https'], true) || isset($parts['user']) || isset($parts['pass']) || isset($parts['port'])) {
            return null;
        }

        $path = trim((string) ($parts['path'] ?? ''), '/');
        $segments = $path === '' ? [] : explode('/', $path);
        parse_str((string) ($parts['query'] ?? ''), $query);

        if ($host === 'youtu.be') {
            return self::youtube($segments[0] ?? null);
        }
        if (in_array($host, self::YOUTUBE_HOSTS, true)) {
            $id = match ($segments[0] ?? '') {
                'watch' => is_string($query['v'] ?? null) ? $query['v'] : null,
                'embed', 'shorts', 'live', 'v' => $segments[1] ?? null,
                default => null,
            };

            return self::youtube($id);
        }
        if (in_array($host, self::VIMEO_HOSTS, true)) {
            return self::vimeo($host, $segments, $query);
        }

        return null;
    }

    /** @return array{provider: 'youtube', id: string, url: string, embed_url: string}|null */
    private static function youtube(?string $id): ?array
    {
        if ($id === null || ! preg_match(self::YOUTUBE_ID, $id)) {
            return null;
        }

        return [
            'provider' => 'youtube',
            'id' => $id,
            'url' => 'https://www.youtube.com/watch?v='.$id,
            'embed_url' => 'https://www.youtube-nocookie.com/embed/'.$id.'?rel=0',
        ];
    }

    /**
     * vimeo.com/{id}, vimeo.com/{id}/{hash} (unlisted), vimeo.com/channels/{name}/{id},
     * player.vimeo.com/video/{id}[?h=hash].
     *
     * @param  list<string>  $segments
     * @param  array<int|string, mixed>  $query
     * @return array{provider: 'vimeo', id: string, url: string, embed_url: string}|null
     */
    private static function vimeo(string $host, array $segments, array $query): ?array
    {
        $id = null;
        $hash = is_string($query['h'] ?? null) ? $query['h'] : null;

        if ($host === 'player.vimeo.com') {
            $id = ($segments[0] ?? '') === 'video' ? ($segments[1] ?? null) : null;
        } elseif (ctype_digit($segments[0] ?? '')) {
            $id = $segments[0];
            $hash ??= $segments[1] ?? null;
        } elseif (($segments[0] ?? '') === 'channels' && count($segments) === 3) {
            $id = $segments[2];
        }

        if ($id === null || ! preg_match('/^[0-9]{5,12}$/', $id)) {
            return null;
        }
        if ($hash !== null && ! preg_match('/^[0-9a-f]{6,20}$/', $hash)) {
            return null;
        }

        return [
            'provider' => 'vimeo',
            'id' => $id,
            'url' => 'https://vimeo.com/'.$id.($hash ? '/'.$hash : ''),
            'embed_url' => 'https://player.vimeo.com/video/'.$id.'?dnt=1'.($hash ? '&h='.$hash : ''),
        ];
    }
}
