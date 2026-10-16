<?php

namespace Tests\Feature\Manage;

use App\Models\Mosque;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Storage;
use Tests\TestCase;

class MosqueSettingsTest extends TestCase
{
    use RefreshDatabase;

    private Mosque $mosque;

    private User $manager;

    protected function setUp(): void
    {
        parent::setUp();
        $this->withoutVite();
        Storage::fake('public');
        $this->mosque = Mosque::factory()->create(['name' => 'Mosquée Al-Nour', 'latitude' => 48.85, 'longitude' => 2.35]);
        $this->manager = User::factory()->create();
        $this->mosque->managers()->attach($this->manager, ['role' => 'owner']);
    }

    private function update(array $data)
    {
        return $this->actingAs($this->manager)
            ->from("/manage/{$this->mosque->slug}")
            ->put("/manage/{$this->mosque->slug}", $data);
    }

    public function test_managers_update_the_page_details(): void
    {
        $this->update([
            'description' => "Cours d'arabe le samedi.\nBienvenue à tous.",
            'association' => 'Association Al-Nour',
            'website' => 'https://al-nour.example.org',
            'phone' => '+33 1 23 45 67 89',
            'email' => 'contact@al-nour.example.org',
            'jumua' => '13:30',
            'jumua2' => '14:30',
            'jumua3' => '',
            'jumua_as_dhuhr' => false,
        ])->assertRedirect("/manage/{$this->mosque->slug}")->assertSessionHasNoErrors();

        $mosque = $this->mosque->fresh();
        $this->assertSame('Association Al-Nour', $mosque->association);
        $this->assertSame('13:30', $mosque->jumua);
        $this->assertSame('14:30', $mosque->jumua2);
        $this->assertNull($mosque->jumua3);
        $this->assertStringContainsString('Bienvenue', $mosque->description);
    }

    public function test_managers_cannot_change_name_position_or_verification(): void
    {
        $this->update([
            'description' => 'Updated',
            'name' => 'Another name',
            'latitude' => 10,
            'longitude' => 10,
            'verified_at' => now()->toDateTimeString(),
            'slug' => 'stolen-slug',
            'source' => 'manual',
        ])->assertSessionHasNoErrors();

        $mosque = $this->mosque->fresh();
        $this->assertSame('Updated', $mosque->description);
        $this->assertSame('Mosquée Al-Nour', $mosque->name);
        $this->assertSame(48.85, $mosque->latitude);
        $this->assertSame(2.35, $mosque->longitude);
        $this->assertNull($mosque->verified_at);
        $this->assertSame($this->mosque->slug, $mosque->slug);
    }

    public function test_details_are_validated(): void
    {
        $this->update([
            'website' => 'javascript:alert(1)',
            'email' => 'not-an-email',
            'jumua' => '25:00',
            'phone' => '<script>',
            'description' => str_repeat('a', 5001),
        ])->assertSessionHasErrors(['website', 'email', 'jumua', 'phone', 'description']);

        $this->assertNull($this->mosque->fresh()->website);
    }

    public function test_logo_and_cover_are_stored_as_webp_and_replaced(): void
    {
        $this->update([
            'logo' => UploadedFile::fake()->image('logo.png', 800, 800),
            'cover' => UploadedFile::fake()->image('cover.jpg', 3000, 1000),
        ])->assertSessionHasNoErrors();

        $mosque = $this->mosque->fresh();
        $this->assertStringStartsWith("mosques/{$mosque->id}/", $mosque->logo_path);
        $this->assertStringEndsWith('.webp', $mosque->logo_path);
        Storage::disk('public')->assertExists([$mosque->logo_path, $mosque->cover_path]);
        [$width] = getimagesizefromstring(Storage::disk('public')->get($mosque->logo_path));
        $this->assertSame(512, $width);   // scaled down

        $oldLogo = $mosque->logo_path;
        $this->update(['logo' => UploadedFile::fake()->image('new.png', 300, 300)])->assertSessionHasNoErrors();

        $mosque->refresh();
        $this->assertNotSame($oldLogo, $mosque->logo_path);
        Storage::disk('public')->assertMissing($oldLogo);
        Storage::disk('public')->assertExists($mosque->logo_path);

        $cover = $mosque->cover_path;
        $this->update(['remove_cover' => true])->assertSessionHasNoErrors();
        $this->assertNull($mosque->fresh()->cover_path);
        Storage::disk('public')->assertMissing($cover);
    }

    public function test_only_reasonable_images_are_accepted(): void
    {
        $this->update(['logo' => UploadedFile::fake()->create('logo.pdf', 100, 'application/pdf')])
            ->assertSessionHasErrors('logo');
        $this->update(['logo' => UploadedFile::fake()->create('logo.svg', 10, 'image/svg+xml')])
            ->assertSessionHasErrors('logo');
        $this->update(['cover' => UploadedFile::fake()->image('cover.jpg', 1200, 400)->size(5000)])
            ->assertSessionHasErrors('cover');

        $this->assertNull($this->mosque->fresh()->logo_path);
        $this->assertEmpty(Storage::disk('public')->allFiles());
    }

    public function test_an_unreadable_second_picture_leaves_no_orphan_file(): void
    {
        // A PNG whose header (size, type) is fine but whose pixels cannot be decoded.
        $blank = imagecreatetruecolor(300, 100);
        ob_start();
        imagepng($blank);
        $broken = substr((string) ob_get_clean(), 0, 33).str_repeat("\x00", 64);

        $this->update([
            'logo' => UploadedFile::fake()->image('logo.png', 400, 400),
            'cover' => UploadedFile::fake()->createWithContent('cover.png', $broken),
        ])->assertSessionHasErrors('cover');

        $mosque = $this->mosque->fresh();
        $this->assertNull($mosque->logo_path);
        $this->assertNull($mosque->cover_path);
        $this->assertEmpty(Storage::disk('public')->allFiles());
    }

    public function test_a_partial_update_keeps_the_jumua_at_dhuhr_choice(): void
    {
        $this->update(['jumua_as_dhuhr' => true])->assertSessionHasNoErrors();
        $this->update(['description' => 'Bienvenue'])->assertSessionHasNoErrors();

        $this->assertTrue($this->mosque->fresh()->jumua_as_dhuhr);
        $this->update(['jumua_as_dhuhr' => false])->assertSessionHasNoErrors();
        $this->assertFalse($this->mosque->fresh()->jumua_as_dhuhr);
    }
}
