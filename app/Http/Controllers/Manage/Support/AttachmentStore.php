<?php

namespace App\Http\Controllers\Manage\Support;

use App\Models\Mosque;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;
use Illuminate\Validation\ValidationException;

/**
 * PDF attachments of a mosque's posts (khutbah texts, programmes), on the
 * public disk under mosques/{id}/files/. The stored name is made of safe
 * characters only, with a random part so it cannot be guessed or collide;
 * the original name is kept separately for the download link.
 */
class AttachmentStore
{
    private const DISK = 'public';

    /** @return array{path: string, name: string} */
    public function store(Mosque $mosque, UploadedFile $file, string $field): array
    {
        $handle = @fopen((string) $file->getRealPath(), 'rb');
        $head = $handle ? (string) fread($handle, 5) : '';
        if ($handle) {
            fclose($handle);
        }
        if ($head !== '%PDF-') {
            throw ValidationException::withMessages([$field => ui('manage.attachment_unreadable')]);
        }

        $name = self::displayName($file->getClientOriginalName());
        $base = Str::limit(Str::slug(pathinfo($name, PATHINFO_FILENAME)), 60, '') ?: 'document';
        $path = "mosques/{$mosque->id}/files/".trim($base, '-').'-'.Str::lower(Str::random(12)).'.pdf';

        Storage::disk(self::DISK)->putFileAs(dirname($path), $file, basename($path), 'public');

        return ['path' => $path, 'name' => $name];
    }

    /** Deletes a file previously stored for this mosque (never anything outside its folder). */
    public function delete(Mosque $mosque, ?string $path): void
    {
        if ($path && str_starts_with($path, "mosques/{$mosque->id}/files/") && ! str_contains($path, '..')) {
            Storage::disk(self::DISK)->delete($path);
        }
    }

    /**
     * The name shown on the download link: no folders, no control characters,
     * ".pdf" at the end. Bidirectional controls go too: "x\u{202E}fdp.exe.pdf"
     * would otherwise read as "xfdp.pdf.exe" and fake another kind of file.
     */
    public static function displayName(string $original): string
    {
        $name = basename(str_replace('\\', '/', $original));
        $name = preg_replace('/[\x00-\x1F\x7F<>:"|?*\x{061C}\x{200E}\x{200F}\x{202A}-\x{202E}\x{2066}-\x{2069}]+/u', '', $name) ?? '';
        $name = trim(preg_replace('/\s+/u', ' ', $name) ?? '', " .\t");
        if (! mb_check_encoding($name, 'UTF-8') || $name === '') {
            $name = 'document';
        }
        $stem = preg_replace('/\.pdf$/i', '', $name) ?? $name;

        return mb_substr($stem, 0, 190).'.pdf';
    }
}
