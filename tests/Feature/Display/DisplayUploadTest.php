<?php

namespace Tests\Feature\Display;

use App\Models\Mosque;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Storage;
use Tests\TestCase;

class DisplayUploadTest extends TestCase
{
    use DisplayFixtures, RefreshDatabase;

    private Mosque $mosque;

    private User $manager;

    protected function setUp(): void
    {
        parent::setUp();
        Storage::fake('public');
        $this->mosque = $this->mosque();
        $this->manager = $this->managerOf($this->mosque);
    }

    private function mp3(string $name = 'adhan.mp3', int $kb = 40): UploadedFile
    {
        return UploadedFile::fake()->createWithContent($name, "ID3\x04\x00\x00\x00\x00\x00\x00".str_repeat("\xFF\xFB\x90\x64".str_repeat("\x00", 252), $kb * 4));
    }

    public function test_a_background_picture_is_re_encoded_in_the_mosques_folder(): void
    {
        $this->actingAs($this->manager)
            ->post("/manage/{$this->mosque->slug}/display/background", ['background' => UploadedFile::fake()->image('hall.jpg', 1920, 1080)])
            ->assertRedirect()
            ->assertSessionHasNoErrors();

        $path = $this->mosque->displaySetting()->first()->background_path;
        $this->assertMatchesRegularExpression("#^display/{$this->mosque->id}/[A-Za-z0-9]{40}\.webp$#", $path);
        Storage::disk('public')->assertExists($path);
        $this->getJson("/mosques/{$this->mosque->slug}/display.json")->assertJsonPath('background_url', asset('storage/'.$path));

        // Replacing it deletes the old file; removing it deletes the new one.
        $this->actingAs($this->manager)->post("/manage/{$this->mosque->slug}/display/background", ['background' => UploadedFile::fake()->image('new.png', 800, 600)]);
        Storage::disk('public')->assertMissing($path);
        $second = $this->mosque->displaySetting()->first()->background_path;

        $this->actingAs($this->manager)->delete("/manage/{$this->mosque->slug}/display/background")->assertRedirect();
        Storage::disk('public')->assertMissing($second);
        $this->assertNull($this->mosque->displaySetting()->first()->background_path);
    }

    public function test_background_uploads_are_validated(): void
    {
        $url = "/manage/{$this->mosque->slug}/display/background";

        $this->actingAs($this->manager)->post($url, ['background' => UploadedFile::fake()->image('huge.jpg', 1920, 1080)->size(6000)])
            ->assertSessionHasErrors('background');
        $this->actingAs($this->manager)->post($url, ['background' => UploadedFile::fake()->create('notes.pdf', 100, 'application/pdf')])
            ->assertSessionHasErrors('background');
        $this->actingAs($this->manager)->post($url, ['background' => UploadedFile::fake()->createWithContent('fake.jpg', '<?php echo 1;')])
            ->assertSessionHasErrors('background');
        $this->actingAs($this->manager)->post($url, ['background' => UploadedFile::fake()->image('tiny.png', 50, 50)])
            ->assertSessionHasErrors('background');
        $this->actingAs($this->manager)->post($url, [])->assertSessionHasErrors('background');

        $this->assertSame([], Storage::disk('public')->allFiles());
    }

    public function test_a_phone_photo_is_turned_upright_before_its_exif_data_is_dropped(): void
    {
        // A portrait photo as phones store it: 400 x 320 pixels, EXIF "rotate 90° clockwise".
        $this->actingAs($this->manager)
            ->post("/manage/{$this->mosque->slug}/display/background", ['background' => $this->jpegWithOrientation(400, 320, 6)])
            ->assertSessionHasNoErrors();

        $path = $this->mosque->displaySetting()->first()->background_path;
        [$width, $height] = getimagesizefromstring((string) Storage::disk('public')->get($path));
        $this->assertSame([320, 400], [$width, $height]);
    }

    public function test_pictures_with_too_many_pixels_are_refused_before_decoding(): void
    {
        $url = "/manage/{$this->mosque->slug}/display/background";

        // A small file whose header announces 8000 x 6000 pixels (48 MP).
        $this->actingAs($this->manager)->post($url, ['background' => $this->pngHeader('bomb.png', 8000, 6000)])
            ->assertSessionHasErrors(['background' => ui('display.upload_image_too_large')]);
        // Wider than any screen needs.
        $this->actingAs($this->manager)->post($url, ['background' => $this->pngHeader('strip.png', 12001, 400)])
            ->assertSessionHasErrors('background');

        $this->assertSame([], Storage::disk('public')->allFiles());
        $this->assertNull($this->mosque->displaySetting()->first());
    }

    /** A real JPEG with an EXIF APP1 segment holding only the Orientation tag. */
    private function jpegWithOrientation(int $width, int $height, int $orientation): UploadedFile
    {
        $image = imagecreatetruecolor($width, $height);
        imagefilledrectangle($image, 0, 0, intdiv($width, 2), $height, (int) imagecolorallocate($image, 200, 30, 30));
        ob_start();
        imagejpeg($image, null, 90);
        $jpeg = (string) ob_get_clean();

        $tiff = "MM\x00\x2A".pack('N', 8).pack('n', 1)
            .pack('nnNn', 0x0112, 3, 1, $orientation)."\x00\x00"
            .pack('N', 0);
        $app1 = "\xFF\xE1".pack('n', strlen($tiff) + 8)."Exif\x00\x00".$tiff;

        return UploadedFile::fake()->createWithContent('portrait.jpg', substr($jpeg, 0, 2).$app1.substr($jpeg, 2));
    }

    /** Only a PNG signature and header: enough for the size checks, never decoded. */
    private function pngHeader(string $name, int $width, int $height): UploadedFile
    {
        $chunk = fn (string $type, string $data) => pack('N', strlen($data)).$type.$data.pack('N', crc32($type.$data));
        $png = "\x89PNG\r\n\x1a\n".$chunk('IHDR', pack('NNCCCCC', $width, $height, 8, 2, 0, 0, 0))
            .$chunk('IDAT', (string) gzcompress(str_repeat("\x00", 64))).$chunk('IEND', '');

        return UploadedFile::fake()->createWithContent($name, $png);
    }

    public function test_the_mosques_own_adhan_is_stored_and_offered(): void
    {
        $this->actingAs($this->manager)
            ->post("/manage/{$this->mosque->slug}/display/adhan", ['adhan' => $this->mp3()])
            ->assertRedirect()
            ->assertSessionHasNoErrors();

        $path = $this->mosque->displaySetting()->first()->adhan_audio_path;
        $this->assertMatchesRegularExpression("#^adhan/mosques/{$this->mosque->id}/[A-Za-z0-9]{40}\.mp3$#", $path);
        Storage::disk('public')->assertExists($path);
        $this->getJson("/adhan/catalog.json?mosque={$this->mosque->slug}")->assertJsonPath('adhans.0.id', "mosque:{$this->mosque->id}");

        $this->actingAs($this->manager)->delete("/manage/{$this->mosque->slug}/display/adhan")->assertRedirect();
        Storage::disk('public')->assertMissing($path);
    }

    public function test_adhan_uploads_are_validated(): void
    {
        $url = "/manage/{$this->mosque->slug}/display/adhan";

        $this->actingAs($this->manager)->post($url, ['adhan' => $this->mp3('big.mp3', 10300)])->assertSessionHasErrors('adhan');
        $this->actingAs($this->manager)->post($url, ['adhan' => UploadedFile::fake()->createWithContent('adhan.mp3', str_repeat('not audio ', 3000))])
            ->assertSessionHasErrors('adhan');
        $this->actingAs($this->manager)->post($url, ['adhan' => UploadedFile::fake()->image('adhan.png')])->assertSessionHasErrors('adhan');

        $this->assertSame([], Storage::disk('public')->allFiles());
    }

    public function test_uploads_by_someone_else_are_refused(): void
    {
        $this->actingAs(User::factory()->create())
            ->post("/manage/{$this->mosque->slug}/display/adhan", ['adhan' => $this->mp3()])
            ->assertForbidden();
        $this->actingAs($this->managerOf(Mosque::factory()->create()))
            ->post("/manage/{$this->mosque->slug}/display/background", ['background' => UploadedFile::fake()->image('x.jpg', 800, 600)])
            ->assertForbidden();

        $this->assertSame([], Storage::disk('public')->allFiles());
    }
}
