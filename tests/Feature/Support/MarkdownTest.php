<?php

namespace Tests\Feature\Support;

use App\Support\Markdown;
use Tests\TestCase;

class MarkdownTest extends TestCase
{
    public function test_images_from_other_sites_become_links(): void
    {
        $html = Markdown::toHtml('![pixel](https://tracker.example/p.gif)');

        $this->assertStringNotContainsString('<img', $html);
        $this->assertStringContainsString('href="https://tracker.example/p.gif"', $html);
        $this->assertStringContainsString('rel="nofollow noopener noreferrer"', $html);
    }

    public function test_images_stored_on_this_site_are_kept(): void
    {
        $this->assertStringContainsString('<img src="/storage/mosques/1/a.webp"', Markdown::toHtml('![a](/storage/mosques/1/a.webp)'));
        $this->assertStringNotContainsString('<img', Markdown::toHtml('![a](//evil.example/storage/x.png)'));
    }

    public function test_raw_html_and_unsafe_links_are_removed(): void
    {
        $html = Markdown::toHtml("<script>alert(1)</script>\n\n[x](javascript:alert(1))");

        $this->assertStringNotContainsString('<script', $html);
        $this->assertStringNotContainsString('javascript:', $html);
    }
}
