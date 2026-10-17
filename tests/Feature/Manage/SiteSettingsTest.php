<?php

namespace Tests\Feature\Manage;

use App\Models\Mosque;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\Feature\MosqueSite\BuildsMosqueSites;
use Tests\TestCase;

/** The look of a mosque's site: tagline, colour and social accounts. */
class SiteSettingsTest extends TestCase
{
    use BuildsMosqueSites, RefreshDatabase;

    private Mosque $mosque;

    private User $manager;

    protected function setUp(): void
    {
        parent::setUp();
        $this->withoutVite();
        $this->mosque = Mosque::factory()->create();
        $this->manager = $this->managerOf($this->mosque);
    }

    private function update(array $data)
    {
        return $this->actingAs($this->manager)
            ->from("/manage/{$this->mosque->slug}/details")
            ->put("/manage/{$this->mosque->slug}", $data);
    }

    public function test_managers_set_a_tagline_a_colour_and_social_accounts(): void
    {
        $this->update([
            'tagline' => 'Un lieu de prière et de savoir',
            'accent_color' => '#1459B8',
            'social_links' => [
                'facebook' => 'facebook.com/mosquee.elhouda',
                'instagram' => '@elhouda',
                'whatsapp' => '+33 6 12 34 56 78',
                'x' => '',
            ],
        ])->assertRedirect("/manage/{$this->mosque->slug}/details")->assertSessionHasNoErrors();

        $mosque = $this->mosque->fresh();
        $this->assertSame('Un lieu de prière et de savoir', $mosque->tagline);
        $this->assertSame('#1459b8', $mosque->accent_color);
        // jsonb keeps its own key order: compare as a map.
        $this->assertEquals([
            'facebook' => 'https://facebook.com/mosquee.elhouda',
            'instagram' => 'https://www.instagram.com/elhouda',
            'whatsapp' => 'https://wa.me/33612345678',
        ], $mosque->social_links);

        // Emptying every field removes them.
        $this->update(['accent_color' => '', 'social_links' => ['facebook' => '', 'instagram' => '', 'whatsapp' => '']])
            ->assertSessionHasNoErrors();
        $this->assertNull($this->mosque->fresh()->accent_color);
        $this->assertNull($this->mosque->fresh()->social_links);
    }

    public function test_colours_and_social_accounts_are_validated(): void
    {
        $this->update([
            'accent_color' => 'red; background:url(x)',
            'tagline' => str_repeat('t', 201),
            'social_links' => ['facebook' => 'https://evil.example/x', 'instagram' => 'javascript:alert(1)'],
        ])->assertSessionHasErrors(['accent_color', 'tagline', 'social_links.facebook', 'social_links.instagram']);

        $this->update(['social_links' => ['myspace' => 'https://myspace.com/x']])->assertSessionHasErrors('social_links');
        $this->update(['social_links' => 'https://facebook.com/x'])->assertSessionHasErrors('social_links');

        $this->assertNull($this->mosque->fresh()->accent_color);
        $this->assertNull($this->mosque->fresh()->social_links);
    }

    public function test_leaving_social_links_out_keeps_them(): void
    {
        $this->mosque->forceFill(['social_links' => ['telegram' => 'https://t.me/elhouda_info']])->save();

        $this->update(['tagline' => 'Bienvenue'])->assertSessionHasNoErrors();

        $this->assertSame(['telegram' => 'https://t.me/elhouda_info'], $this->mosque->fresh()->social_links);
    }

    public function test_others_cannot_change_the_look_of_the_site(): void
    {
        $stranger = $this->managerOf(Mosque::factory()->create());

        $this->actingAs($stranger)->put("/manage/{$this->mosque->slug}", ['tagline' => 'Piraté', 'accent_color' => '#000000'])
            ->assertForbidden();
        $this->assertNull($this->mosque->fresh()->tagline);
    }
}
