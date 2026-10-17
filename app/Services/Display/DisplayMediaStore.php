<?php

namespace App\Services\Display;

use App\Models\Mosque;
use GdImage;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;
use Illuminate\Validation\ValidationException;

/**
 * A mosque's display files on the public disk: the background picture
 * (display/{id}/, re-encoded as WebP so EXIF data — phone GPS positions —
 * is dropped and a file that only pretends to be an image is refused) and
 * its own adhan recording (adhan/mosques/{id}/, checked to really be MP3).
 */
class DisplayMediaStore
{
    private const DISK = 'public';

    /** A 4K screen's longest side. */
    private const MAX_SIDE = 3840;

    /**
     * Pixels decoded at most (about 160 MB in memory): a photo from a phone
     * fits, a small file that unpacks into a gigantic picture does not.
     */
    public const MAX_PIXELS = 40_000_000;

    public function storeBackground(Mosque $mosque, UploadedFile $file): string
    {
        $source = (string) $file->getRealPath();
        // Read from the header before decoding anything.
        $info = @getimagesize($source);
        if (! is_array($info) || $info[0] < 1 || $info[1] < 1) {
            throw ValidationException::withMessages(['background' => ui('display.upload_image_unreadable')]);
        }
        if ($info[0] * $info[1] > self::MAX_PIXELS) {
            throw ValidationException::withMessages(['background' => ui('display.upload_image_too_large')]);
        }

        $image = @imagecreatefromstring((string) file_get_contents($source));
        if (! $image instanceof GdImage) {
            throw ValidationException::withMessages(['background' => ui('display.upload_image_unreadable')]);
        }
        imagepalettetotruecolor($image);
        $image = $this->scaled($image);
        // Re-encoding drops the EXIF data, so a phone photo's rotation is applied first.
        $image = $this->upright($image, $source, (int) $info[2]);

        ob_start();
        imagewebp($image, null, 84);
        $binary = (string) ob_get_clean();
        unset($image);

        $path = self::backgroundFolder($mosque).'/'.Str::random(40).'.webp';
        Storage::disk(self::DISK)->put($path, $binary, 'public');

        return $path;
    }

    public function storeAdhan(Mosque $mosque, UploadedFile $file): string
    {
        $handle = @fopen($file->getRealPath(), 'rb');
        $head = $handle ? (string) fread($handle, 4) : '';
        if ($handle) {
            fclose($handle);
        }
        if (! self::looksLikeMp3($head)) {
            throw ValidationException::withMessages(['adhan' => ui('display.upload_audio_unreadable')]);
        }

        $path = self::adhanFolder($mosque).'/'.Str::random(40).'.mp3';
        Storage::disk(self::DISK)->putFileAs(dirname($path), $file, basename($path), 'public');

        return $path;
    }

    /** Deletes a file stored for this mosque (never anything outside its own folders). */
    public function delete(Mosque $mosque, ?string $path): void
    {
        if (! $path || str_contains($path, '..')) {
            return;
        }
        if (str_starts_with($path, self::backgroundFolder($mosque).'/') || str_starts_with($path, self::adhanFolder($mosque).'/')) {
            Storage::disk(self::DISK)->delete($path);
        }
    }

    /** An ID3 tag or an MPEG audio frame header. */
    public static function looksLikeMp3(string $head): bool
    {
        if (str_starts_with($head, 'ID3')) {
            return true;
        }

        return strlen($head) >= 2 && ord($head[0]) === 0xFF && (ord($head[1]) & 0xE0) === 0xE0;
    }

    public static function backgroundFolder(Mosque $mosque): string
    {
        return "display/{$mosque->id}";
    }

    public static function adhanFolder(Mosque $mosque): string
    {
        return AdhanCatalog::folder()."/mosques/{$mosque->id}";
    }

    /** Turns a JPEG the way its EXIF orientation says (phones store portrait photos sideways). */
    private function upright(GdImage $image, string $source, int $type): GdImage
    {
        if ($type !== IMAGETYPE_JPEG || ! function_exists('exif_read_data')) {
            return $image;
        }
        $exif = @exif_read_data($source);
        $orientation = is_array($exif) ? (int) ($exif['Orientation'] ?? 1) : 1;
        // imagerotate() turns counter-clockwise.
        $turn = match ($orientation) {
            3 => 180,
            5, 6 => 270,
            7, 8 => 90,
            default => 0,
        };
        if ($turn !== 0) {
            $turned = imagerotate($image, $turn, 0);
            $image = $turned instanceof GdImage ? $turned : $image;
        }
        $flip = match ($orientation) {
            2, 5, 7 => IMG_FLIP_HORIZONTAL,
            4 => IMG_FLIP_VERTICAL,
            default => null,
        };
        if ($flip !== null) {
            imageflip($image, $flip);
        }

        return $image;
    }

    private function scaled(GdImage $image): GdImage
    {
        $width = imagesx($image);
        $height = imagesy($image);
        $longest = max($width, $height);
        if ($longest <= self::MAX_SIDE) {
            return $image;
        }
        $ratio = self::MAX_SIDE / $longest;
        $scaled = imagescale($image, max(1, (int) round($width * $ratio)), max(1, (int) round($height * $ratio)));

        return $scaled instanceof GdImage ? $scaled : $image;
    }
}
