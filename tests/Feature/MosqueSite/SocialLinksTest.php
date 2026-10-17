<?php

namespace Tests\Feature\MosqueSite;

use App\Http\Controllers\MosquePage\Support\SocialLinks;
use PHPUnit\Framework\Attributes\DataProvider;
use Tests\TestCase;

/** Social accounts: a link of the network itself, or a handle; nothing else. */
class SocialLinksTest extends TestCase
{
    /** @return array<string, array{0: string, 1: string, 2: string|null}> */
    public static function cases(): array
    {
        return [
            'facebook page' => ['facebook', 'https://www.facebook.com/mosquee.elhouda/', 'https://www.facebook.com/mosquee.elhouda'],
            'facebook without scheme' => ['facebook', 'facebook.com/mosquee.elhouda', 'https://facebook.com/mosquee.elhouda'],
            'facebook profile id' => ['facebook', 'https://www.facebook.com/profile.php?id=100064123456789', 'https://www.facebook.com/profile.php?id=100064123456789'],
            'facebook handle' => ['facebook', 'mosquee.elhouda', 'https://www.facebook.com/mosquee.elhouda'],
            'instagram handle' => ['instagram', '@mosquee_elhouda', 'https://www.instagram.com/mosquee_elhouda'],
            'youtube handle' => ['youtube', '@MosqueeElHouda', 'https://www.youtube.com/@MosqueeElHouda'],
            'youtube channel' => ['youtube', 'https://www.youtube.com/channel/UC1234567890', 'https://www.youtube.com/channel/UC1234567890'],
            'x handle' => ['x', '@elhouda69', 'https://x.com/elhouda69'],
            'twitter link' => ['x', 'https://twitter.com/elhouda69', 'https://twitter.com/elhouda69'],
            'tiktok handle' => ['tiktok', 'elhouda.69', 'https://www.tiktok.com/@elhouda.69'],
            'whatsapp number' => ['whatsapp', '+33 6 12 34 56 78', 'https://wa.me/33612345678'],
            'whatsapp group' => ['whatsapp', 'https://chat.whatsapp.com/AbCdEf123', 'https://chat.whatsapp.com/AbCdEf123'],
            'telegram handle' => ['telegram', '@elhouda_info', 'https://t.me/elhouda_info'],
            'wrong network' => ['instagram', 'https://www.facebook.com/elhouda', null],
            'lookalike host' => ['facebook', 'https://facebook.com.evil.example/x', null],
            'javascript' => ['x', 'javascript:alert(1)', null],
            'bare domain' => ['facebook', 'facebook.com', null],
            'root only' => ['youtube', 'https://www.youtube.com/', null],
            'query injection' => ['instagram', 'https://www.instagram.com/x?next=https://evil.example', 'https://www.instagram.com/x'],
            'html' => ['tiktok', '<script>', null],
        ];
    }

    #[DataProvider('cases')]
    public function test_links_and_handles_become_clean_addresses(string $network, string $input, ?string $expected): void
    {
        $this->assertSame($expected, SocialLinks::normalize($network, $input));
    }

    public function test_stored_links_are_rechecked_when_shown(): void
    {
        $this->assertSame(
            [['network' => 'facebook', 'url' => 'https://www.facebook.com/a.b.c'], ['network' => 'telegram', 'url' => 'https://t.me/abcdef']],
            SocialLinks::present(['telegram' => 'https://t.me/abcdef', 'facebook' => 'https://www.facebook.com/a.b.c', 'instagram' => 'javascript:x', 'myspace' => 'https://myspace.com/x']),
        );
        $this->assertSame([], SocialLinks::present('not an array'));
    }
}
