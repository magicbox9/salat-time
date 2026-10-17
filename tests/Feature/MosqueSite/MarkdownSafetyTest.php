<?php

namespace Tests\Feature\MosqueSite;

use App\Models\Mosque;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\RateLimiter;
use Inertia\Testing\AssertableInertia as Assert;
use Tests\TestCase;

/** Markdown from managers never carries scripts, raw HTML or dangerous links to visitors. */
class MarkdownSafetyTest extends TestCase
{
    use BuildsMosqueSites, RefreshDatabase;

    private const HOSTILE = <<<'MD'
        # Titre

        <script>alert('xss')</script>
        <img src=x onerror="alert(1)">
        <iframe src="https://evil.example"></iframe>

        [cliquez](javascript:alert(1)) et [ici](data:text/html;base64,PHNjcmlwdD4=) et [vbs](vbscript:msgbox)

        [site](https://example.org)
        MD;

    protected function setUp(): void
    {
        parent::setUp();
        $this->withoutVite();
    }

    private function assertSafe(string $html): void
    {
        $lower = strtolower($html);
        foreach (['<script', 'onerror', '<iframe', 'javascript:', 'data:text/html', 'vbscript:'] as $needle) {
            $this->assertStringNotContainsString($needle, $lower, "found $needle");
        }
        $this->assertStringContainsString('<h1>Titre</h1>', $html);
        $this->assertStringContainsString('href="https://example.org"', $html);
    }

    public function test_articles_and_pages_are_rendered_safely(): void
    {
        $mosque = Mosque::factory()->create();
        $this->blogPost($mosque, ['slug' => 'hostile', 'body' => self::HOSTILE]);
        $this->sitePage($mosque, ['slug' => 'hostile', 'body' => self::HOSTILE]);

        $this->get("/mosques/{$mosque->slug}/blog/hostile")
            ->assertInertia(fn (Assert $page) => $page->where('post.body_html', function (string $html) {
                $this->assertSafe($html);

                return true;
            }));
        $this->get("/mosques/{$mosque->slug}/pages/hostile")
            ->assertInertia(fn (Assert $page) => $page->where('page.body_html', function (string $html) {
                $this->assertSafe($html);

                return true;
            }));
    }

    public function test_the_live_preview_is_rendered_by_the_server_with_the_same_rules(): void
    {
        $mosque = Mosque::factory()->create();
        $manager = $this->managerOf($mosque);

        $html = $this->actingAs($manager)
            ->postJson("/manage/{$mosque->slug}/markdown-preview", ['body' => self::HOSTILE])
            ->assertOk()
            ->json('html');
        $this->assertSafe($html);

        $this->actingAs($manager)->postJson("/manage/{$mosque->slug}/markdown-preview", ['body' => ''])
            ->assertOk()
            ->assertJsonPath('html', '');
        $this->actingAs($manager)->postJson("/manage/{$mosque->slug}/markdown-preview", ['body' => str_repeat('a', 50001)])
            ->assertUnprocessable();
        $this->actingAs($manager)->postJson("/manage/{$mosque->slug}/markdown-preview", ['body' => "a\0b"])
            ->assertUnprocessable();
    }

    public function test_only_the_mosque_s_managers_get_a_preview(): void
    {
        $mosque = Mosque::factory()->create();
        $this->managerOf(Mosque::factory()->create());

        $this->postJson("/manage/{$mosque->slug}/markdown-preview", ['body' => 'x'])->assertUnauthorized();
        $this->actingAs(User::factory()->create())
            ->postJson("/manage/{$mosque->slug}/markdown-preview", ['body' => 'x'])
            ->assertForbidden();
        $this->actingAs($this->admin())
            ->postJson("/manage/{$mosque->slug}/markdown-preview", ['body' => '**x**'])
            ->assertOk();
    }

    public function test_the_preview_is_throttled(): void
    {
        $mosque = Mosque::factory()->create();
        $manager = $this->managerOf($mosque);
        RateLimiter::clear('manage-markdown-preview');

        for ($i = 0; $i < 60; $i++) {
            $this->actingAs($manager)->postJson("/manage/{$mosque->slug}/markdown-preview", ['body' => 'x'])->assertOk();
        }

        $this->actingAs($manager)->postJson("/manage/{$mosque->slug}/markdown-preview", ['body' => 'x'])
            ->assertTooManyRequests();
    }
}
