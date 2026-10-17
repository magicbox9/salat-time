<?php

namespace App\Services\Display;

use App\Models\Mosque;
use Illuminate\Contracts\Filesystem\Filesystem;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;

/**
 * The adhan recordings a screen can play: the files `php artisan adhan:fetch`
 * placed in storage/app/public/adhan (curated names first, in the Mac app's
 * order), any other MP3 dropped in that folder, and a mosque's own upload.
 * Only files that really exist are listed, so the list may be empty.
 */
class AdhanCatalog
{
    public const DISK = 'public';

    /** @return list<array{id: string, name: string, url: string}> */
    public function list(?Mosque $mosque = null): array
    {
        $disk = $this->disk();
        $folder = trim((string) config('display.adhan.folder', 'adhan'), '/');
        $minBytes = (int) config('display.adhan.min_bytes', 20000);
        $present = array_flip($disk->files($folder));
        $tracks = [];
        $known = [];

        foreach ((array) config('display.adhan.recordings') as $recording) {
            $path = "$folder/{$recording['file']}";
            $known[$path] = true;
            if (isset($present[$path]) && $disk->size($path) >= $minBytes) {
                $tracks[] = ['id' => $recording['id'], 'name' => $recording['name'], 'url' => $this->url($path)];
            }
        }

        foreach (array_keys($present) as $path) {
            $base = basename($path, '.mp3');
            // "file:" + at most 59 characters: an id the settings accept (64 at most).
            if (isset($known[$path]) || ! str_ends_with($path, '.mp3') || ! preg_match('/^[A-Za-z0-9_-]{1,59}$/', $base)) {
                continue;
            }
            if ($disk->size($path) >= $minBytes) {
                $tracks[] = ['id' => 'file:'.$base, 'name' => Str::headline(Str::after($base, 'adhan_')), 'url' => $this->url($path)];
            }
        }

        if ($own = $this->mosqueTrack($mosque)) {
            $tracks[] = $own;
        }

        return $tracks;
    }

    /** @return array{id: string, name: string, url: string}|null */
    public function mosqueTrack(?Mosque $mosque): ?array
    {
        $path = $mosque?->displaySetting?->adhan_audio_path;
        if (! $mosque || ! is_string($path) || ! $this->disk()->exists($path)) {
            return null;
        }

        return ['id' => self::mosqueId($mosque), 'name' => $mosque->name, 'url' => $this->url($path)];
    }

    public static function mosqueId(Mosque $mosque): string
    {
        return 'mosque:'.$mosque->id;
    }

    public static function folder(): string
    {
        return trim((string) config('display.adhan.folder', 'adhan'), '/');
    }

    private function url(string $path): string
    {
        return asset('storage/'.$path);
    }

    private function disk(): Filesystem
    {
        return Storage::disk(self::DISK);
    }
}
