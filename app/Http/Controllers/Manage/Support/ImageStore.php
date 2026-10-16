<?php

namespace App\Http\Controllers\Manage\Support;

use App\Models\Mosque;
use GdImage;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;
use Illuminate\Validation\ValidationException;

/**
 * Stores a mosque's uploaded images on the public disk under mosques/{id}/.
 *
 * Every image is decoded and re-encoded as WebP: this drops EXIF data (phone
 * photos carry GPS positions), neutralises files that only pretend to be
 * images, and keeps pages light by capping the longest side.
 */
class ImageStore
{
    private const DISK = 'public';

    /** @return string The stored path, relative to the public disk. */
    public function store(Mosque $mosque, UploadedFile $file, string $field, string $folder = '', int $maxSide = 2000): string
    {
        $image = @imagecreatefromstring((string) file_get_contents($file->getRealPath()));
        if (! $image instanceof GdImage) {
            throw ValidationException::withMessages([$field => ui('manage.image_unreadable')]);
        }

        imagepalettetotruecolor($image);
        $image = $this->scaled($this->upright($image, $file), $maxSide);
        imagealphablending($image, false);
        imagesavealpha($image, true);

        ob_start();
        imagewebp($image, null, 82);
        $binary = (string) ob_get_clean();
        unset($image);

        $path = trim("mosques/{$mosque->id}/".trim($folder, '/'), '/').'/'.Str::random(40).'.webp';
        Storage::disk(self::DISK)->put($path, $binary, 'public');

        return $path;
    }

    /** Deletes a file previously stored for this mosque (never anything outside its folder). */
    public function delete(Mosque $mosque, ?string $path): void
    {
        if ($path && str_starts_with($path, "mosques/{$mosque->id}/") && ! str_contains($path, '..')) {
            Storage::disk(self::DISK)->delete($path);
        }
    }

    /** Applies the EXIF orientation of JPEG photos before the metadata is dropped. */
    private function upright(GdImage $image, UploadedFile $file): GdImage
    {
        if (! function_exists('exif_read_data') || ! in_array($file->getMimeType(), ['image/jpeg', 'image/jpg'], true)) {
            return $image;
        }
        $exif = @exif_read_data($file->getRealPath());
        $angle = match ((int) ($exif['Orientation'] ?? 1)) {
            3 => 180,
            6 => -90,
            8 => 90,
            default => 0,
        };
        if ($angle === 0) {
            return $image;
        }
        $rotated = imagerotate($image, $angle, 0);

        return $rotated instanceof GdImage ? $rotated : $image;
    }

    private function scaled(GdImage $image, int $maxSide): GdImage
    {
        $width = imagesx($image);
        $height = imagesy($image);
        $longest = max($width, $height);
        if ($longest <= $maxSide) {
            return $image;
        }
        $ratio = $maxSide / $longest;
        $scaled = imagescale($image, max(1, (int) round($width * $ratio)), max(1, (int) round($height * $ratio)));

        return $scaled instanceof GdImage ? $scaled : $image;
    }
}
