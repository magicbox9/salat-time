<?php

namespace App\Http\Controllers\MosquePage\Support;

/**
 * A mosque's social accounts. Managers type a link or a handle ("@masjid");
 * only links to the network's own domain are kept, rewritten as a clean
 * https:// address. Anything else is refused.
 */
final class SocialLinks
{
    public const NETWORKS = ['facebook', 'instagram', 'youtube', 'x', 'tiktok', 'whatsapp', 'telegram'];

    /** Domains accepted for each network (and their subdomains listed here only). */
    private const HOSTS = [
        'facebook' => ['facebook.com', 'www.facebook.com', 'm.facebook.com', 'fb.com', 'www.fb.com'],
        'instagram' => ['instagram.com', 'www.instagram.com'],
        'youtube' => ['youtube.com', 'www.youtube.com', 'm.youtube.com'],
        'x' => ['x.com', 'www.x.com', 'twitter.com', 'www.twitter.com', 'mobile.twitter.com'],
        'tiktok' => ['tiktok.com', 'www.tiktok.com'],
        'whatsapp' => ['wa.me', 'chat.whatsapp.com', 'whatsapp.com', 'www.whatsapp.com'],
        'telegram' => ['t.me', 'telegram.me'],
    ];

    /** Bare handles, and the canonical address built from them. */
    private const HANDLES = [
        'facebook' => ['/^@?([A-Za-z0-9.]{3,80})$/', 'https://www.facebook.com/%s'],
        'instagram' => ['/^@?([A-Za-z0-9._]{1,30})$/', 'https://www.instagram.com/%s'],
        'youtube' => ['/^@([A-Za-z0-9._-]{3,30})$/', 'https://www.youtube.com/@%s'],
        'x' => ['/^@?([A-Za-z0-9_]{1,15})$/', 'https://x.com/%s'],
        'tiktok' => ['/^@?([A-Za-z0-9._]{2,24})$/', 'https://www.tiktok.com/@%s'],
        'whatsapp' => ['/^(\+?[0-9][0-9 ().-]{5,24})$/', 'https://wa.me/%s'],
        'telegram' => ['/^@?([A-Za-z0-9_]{5,32})$/', 'https://t.me/%s'],
    ];

    /** The canonical https address for a link or handle, or null when it is not one of the network's. */
    public static function normalize(string $network, ?string $value): ?string
    {
        $value = trim((string) $value);
        if (! isset(self::HOSTS[$network]) || $value === '' || strlen($value) > 300
            || ($network !== 'whatsapp' && preg_match('/\s/', $value))) {
            return null;
        }

        if (! self::looksLikeLink($network, $value)) {
            [$pattern, $format] = self::HANDLES[$network];
            if (! preg_match($pattern, $value, $match)) {
                return null;
            }

            return sprintf($format, $network === 'whatsapp' ? preg_replace('/\D/', '', $match[1]) : $match[1]);
        }

        if (! preg_match('#^https?://#i', $value)) {
            $value = 'https://'.$value;
        }
        $parts = parse_url($value);
        if ($parts === false || isset($parts['user']) || isset($parts['pass']) || isset($parts['port'])) {
            return null;
        }
        $host = strtolower((string) ($parts['host'] ?? ''));
        $path = (string) ($parts['path'] ?? '');
        if (! in_array($host, self::HOSTS[$network], true) || ! preg_match('#^(/[A-Za-z0-9._~@%+-]+)+/?$#', $path)) {
            return null;
        }

        // Facebook pages without a username are addressed as profile.php?id=…
        $search = (string) ($parts['query'] ?? '');
        $query = $network === 'facebook' && preg_match('/^id=\d{5,20}$/', $search) ? '?'.$search : '';

        return 'https://'.$host.rtrim($path, '/').$query;
    }

    private static function looksLikeLink(string $network, string $value): bool
    {
        if (preg_match('#^https?://#i', $value) || str_contains($value, '/')) {
            return true;
        }
        $lower = strtolower($value);
        foreach (self::HOSTS[$network] as $host) {
            if ($lower === $host) {
                return true;
            }
        }

        return false;
    }

    /**
     * Stored links, as a list for the public page (re-checked on the way out).
     *
     * @return list<array{network: string, url: string}>
     */
    public static function present(mixed $stored): array
    {
        if (! is_array($stored)) {
            return [];
        }

        $links = [];
        foreach (self::NETWORKS as $network) {
            $url = is_string($stored[$network] ?? null) ? self::normalize($network, $stored[$network]) : null;
            if ($url !== null) {
                $links[] = ['network' => $network, 'url' => $url];
            }
        }

        return $links;
    }

    /**
     * Every network, as the form shows it ('' when unset).
     *
     * @return array<string, string>
     */
    public static function formValues(mixed $stored): array
    {
        $values = [];
        foreach (self::NETWORKS as $network) {
            $values[$network] = is_array($stored) && is_string($stored[$network] ?? null) ? $stored[$network] : '';
        }

        return $values;
    }
}
