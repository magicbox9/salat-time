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

    /** @return list<array{id: string, name: string, url: string, fajr_url?: string}> */
    public function list(?Mosque $mosque = null): array
    {
        $disk = $this->disk();
        $folder = trim((string) config('display.adhan.folder', 'adhan'), '/');
        $minBytes = (int) config('display.adhan.min_bytes', 20000);
        $present = array_flip($disk->files($folder));
        $tracks = [];
        $known = [];

        // The official Salat Time adhan comes first: it is every app's default.
        $official = (array) config('display.adhan.official');
        $regular = $official['regular'] ?? null;
        $fajr = $official['fajr'] ?? null;
        foreach ([$regular, $fajr] as $entry) {
            if ($entry) {
                $known["$folder/{$entry['file']}"] = true;
            }
        }
        $fajrPath = $fajr ? "$folder/{$fajr['file']}" : null;
        $fajrUrl = $fajrPath && isset($present[$fajrPath]) && $disk->size($fajrPath) >= $minBytes ? $this->url($fajrPath) : null;
        $regularPath = $regular ? "$folder/{$regular['file']}" : null;
        if ($regularPath && isset($present[$regularPath]) && $disk->size($regularPath) >= $minBytes) {
            // fajr_url: the companion played at Fajr when this track is chosen.
            $tracks[] = ['id' => $regular['id'], 'name' => $regular['name'], 'url' => $this->url($regularPath)]
                + ($fajrUrl ? ['fajr_url' => $fajrUrl] : []);
        }
        if ($fajrUrl) {
            $tracks[] = ['id' => $fajr['id'], 'name' => $fajr['name'], 'url' => $fajrUrl];
        }

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
