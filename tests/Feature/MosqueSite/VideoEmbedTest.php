<?php

namespace Tests\Feature\MosqueSite;

use App\Http\Controllers\MosquePage\Support\VideoEmbed;
use PHPUnit\Framework\Attributes\DataProvider;
use Tests\TestCase;

/** Khutbah videos: YouTube and Vimeo only, through their privacy-enhanced players. */
class VideoEmbedTest extends TestCase
{
    /** @return array<string, array{0: string, 1: string}> */
    public static function accepted(): array
    {
        return [
            'youtube watch' => ['https://www.youtube.com/watch?v=dQw4w9WgXcQ&t=42s', 'https://www.youtube-nocookie.com/embed/dQw4w9WgXcQ?rel=0'],
            'youtube short link' => ['https://youtu.be/dQw4w9WgXcQ?si=abc', 'https://www.youtube-nocookie.com/embed/dQw4w9WgXcQ?rel=0'],
            'youtube mobile' => ['http://m.youtube.com/watch?v=dQw4w9WgXcQ', 'https://www.youtube-nocookie.com/embed/dQw4w9WgXcQ?rel=0'],
            'youtube shorts' => ['https://youtube.com/shorts/dQw4w9WgXcQ', 'https://www.youtube-nocookie.com/embed/dQw4w9WgXcQ?rel=0'],
            'youtube live' => ['https://www.youtube.com/live/dQw4w9WgXcQ', 'https://www.youtube-nocookie.com/embed/dQw4w9WgXcQ?rel=0'],
            'youtube embed' => ['https://www.youtube-nocookie.com/embed/dQw4w9WgXcQ', 'https://www.youtube-nocookie.com/embed/dQw4w9WgXcQ?rel=0'],
            'vimeo' => ['https://vimeo.com/76979871', 'https://player.vimeo.com/video/76979871?dnt=1'],
            'vimeo unlisted' => ['https://vimeo.com/76979871/8272103f6e', 'https://player.vimeo.com/video/76979871?dnt=1&h=8272103f6e'],
            'vimeo channel' => ['https://vimeo.com/channels/staffpicks/76979871', 'https://player.vimeo.com/video/76979871?dnt=1'],
            'vimeo player' => ['https://player.vimeo.com/video/76979871', 'https://player.vimeo.com/video/76979871?dnt=1'],
        ];
    }

    #[DataProvider('accepted')]
    public function test_youtube_and_vimeo_links_become_privacy_enhanced_embeds(string $url, string $embed): void
    {
        $this->assertSame($embed, VideoEmbed::parse($url)['embed_url'] ?? null);
    }

    /** @return array<string, array{0: string}> */
    public static function refused(): array
    {
        return [
            'another site' => ['https://evil.example/watch?v=dQw4w9WgXcQ'],
            'lookalike host' => ['https://youtube.com.evil.example/watch?v=dQw4w9WgXcQ'],
            'subdomain trick' => ['https://evil.youtube.com/watch?v=dQw4w9WgXcQ'],
            'javascript' => ['javascript:alert(1)'],
            'data url' => ['data:text/html,<script>alert(1)</script>'],
            'no scheme' => ['//www.youtube.com/watch?v=dQw4w9WgXcQ'],
            'credentials' => ['https://user:pass@www.youtube.com/watch?v=dQw4w9WgXcQ'],
            'port' => ['https://www.youtube.com:8443/watch?v=dQw4w9WgXcQ'],
            'bad youtube id' => ['https://www.youtube.com/watch?v=<script>'],
            'youtube channel' => ['https://www.youtube.com/@mosquee'],
            'bad vimeo id' => ['https://vimeo.com/abc'],
            'bad vimeo hash' => ['https://vimeo.com/76979871/"onload'],
            'dailymotion' => ['https://www.dailymotion.com/video/x7tgad0'],
            'spaces' => ['https://www.youtube.com/watch?v=dQw4w9WgXcQ extra'],
        ];
    }

    #[DataProvider('refused')]
    public function test_everything_else_is_refused(string $url): void
    {
        $this->assertNull(VideoEmbed::parse($url));
    }
}
