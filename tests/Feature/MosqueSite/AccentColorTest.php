<?php

namespace Tests\Feature\MosqueSite;

use App\Http\Controllers\MosquePage\Support\AccentColor;
use App\Models\Mosque;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Inertia\Testing\AssertableInertia as Assert;
use Tests\TestCase;

/** A mosque's colour stays legible: on buttons (foreground) and as text on white (ink). */
class AccentColorTest extends TestCase
{
    use RefreshDatabase;

    public function test_dark_enough_colours_are_their_own_ink(): void
    {
        foreach (['#0f6b56', '#1459b8', '#b82b2b', '#1f2a2e'] as $color) {
            $this->assertSame($color, AccentColor::ink($color));
        }
    }

    public function test_pale_colours_are_darkened_until_they_read_on_white(): void
    {
        foreach (['#ffe066', '#a37a33', '#d16b17', '#ffffff', '#00ff00'] as $color) {
            $ink = AccentColor::ink($color);

            $this->assertMatchesRegularExpression('/^#[0-9a-f]{6}$/', $ink);
            $this->assertGreaterThanOrEqual(4.5, AccentColor::contrast($ink, '#ffffff'), "$color → $ink");
        }
    }

    public function test_the_site_shell_carries_the_ink(): void
    {
        $this->withoutVite();
        $mosque = Mosque::factory()->create(['accent_color' => '#FFE066']);

        $this->get("/mosques/{$mosque->slug}")
            ->assertOk()
            ->assertInertia(fn (Assert $page) => $page
                ->where('site.accent.color', '#ffe066')
                ->where('site.accent.foreground', '#0b1a17')
                ->where('site.accent.ink', AccentColor::ink('#ffe066')));
    }
}
