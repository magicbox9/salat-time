<?php

namespace App\Console\Commands;

use App\Services\Display\AdhanCatalog;
use App\Services\Display\DisplayMediaStore;
use Illuminate\Console\Command;
use Illuminate\Http\Client\ConnectionException;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Process;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Sleep;

/**
 * Downloads the 14 adhan recordings of the Mac app's build.sh (Assabile's
 * curated collection; its media server checks the Referer) into the public
 * disk, adhan/. Files already present are skipped; a download that is too
 * small or is not MP3 is discarded. The rights to these recordings must be
 * cleared with the publisher before a public launch.
 */
class FetchAdhanAudio extends Command
{
    protected $signature = 'adhan:fetch {--force : Download again even when a file is already present}';

    protected $description = 'Download the adhan recordings the display screens can play';

    public function handle(): int
    {
        $config = (array) config('display.adhan');
        $disk = Storage::disk(AdhanCatalog::DISK);
        $folder = AdhanCatalog::folder();
        $minBytes = (int) ($config['min_bytes'] ?? 20000);
        $failed = 0;

        foreach ((array) ($config['recordings'] ?? []) as $index => $recording) {
            $file = (string) $recording['file'];
            $hash = (string) $recording['hash'];
            if (! preg_match('/^adhan_[a-z_]+\.mp3$/', $file) || ! preg_match('/^[a-f0-9]{12}$/', $hash)) {
                $this->warn("  $file: invalid catalog entry, skipped");
                $failed++;

                continue;
            }
            $path = "$folder/$file";
            if (! $this->option('force') && $disk->exists($path) && $disk->size($path) >= $minBytes) {
                $this->line("  $file already present");

                continue;
            }
            // One request at a time, gently.
            if ($index > 0) {
                Sleep::for(300)->milliseconds();
            }

            $body = $this->download(rtrim((string) $config['base_url'], '/')."/$hash.mp3", $config);
            if ($body === null || strlen($body) < $minBytes || ! DisplayMediaStore::looksLikeMp3(substr($body, 0, 4))) {
                $this->warn("  $file skipped (download failed or not an MP3)");
                $failed++;

                continue;
            }
            $disk->put($path, $body, 'public');
            $this->info(sprintf('  %s (%d bytes)', $file, strlen($body)));
        }

        $failed += $this->renderOfficial($config, $folder, $minBytes) ? 0 : 1;

        $this->newLine();
        $this->line('Reminder: clear the rights to these recordings with their publisher before a public launch.');

        return $failed === 0 ? self::SUCCESS : self::FAILURE;
    }

    /**
     * Renders the official Salat Time adhan (config display.adhan.official)
     * from its source recording: each version keeps the listed time ranges,
     * joined in order, re-encoded as MP3 by ffmpeg.
     *
     * @param  array<string, mixed>  $config
     */
    private function renderOfficial(array $config, string $folder, int $minBytes): bool
    {
        $official = (array) ($config['official'] ?? []);
        $disk = Storage::disk(AdhanCatalog::DISK);
        $source = "$folder/".($official['source'] ?? '');
        if (! isset($official['source']) || ! $disk->exists($source)) {
            $this->warn('  official adhan: its source recording is missing, skipped');

            return false;
        }

        $ok = true;
        foreach (['regular', 'fajr'] as $version) {
            $entry = $official[$version] ?? null;
            if (! is_array($entry)) {
                continue;
            }
            $target = "$folder/{$entry['file']}";
            if (! $this->option('force') && $disk->exists($target) && $disk->size($target) >= $minBytes) {
                $this->line("  {$entry['file']} already present");

                continue;
            }
            $result = Process::timeout(120)->run([
                'ffmpeg', '-hide_banner', '-loglevel', 'error', '-y',
                '-i', $disk->path($source),
                '-af', self::selectFilter((array) $entry['keep']),
                '-c:a', 'libmp3lame', '-q:a', '2',
                $disk->path($target),
            ]);
            if (! $result->successful() || ! $disk->exists($target) || $disk->size($target) < $minBytes) {
                $this->warn("  {$entry['file']} not rendered (is ffmpeg installed?) ".trim($result->errorOutput()));
                $ok = false;

                continue;
            }
            $this->info(sprintf('  %s rendered (%d bytes)', $entry['file'], $disk->size($target)));
        }

        return $ok;
    }

    /**
     * ffmpeg filter keeping the given [start, end|null] ranges (seconds).
     *
     * @param  list<array{0: float|int, 1: float|int|null}>  $keep
     */
    public static function selectFilter(array $keep): string
    {
        $parts = array_map(function (array $range): string {
            $start = sprintf('%.3F', (float) $range[0]);

            return $range[1] === null ? "gte(t\\,$start)" : sprintf('between(t\\,%s\\,%.3F)', $start, (float) $range[1]);
        }, $keep);

        return "aselect='".implode('+', $parts)."',asetpts=N/SR/TB";
    }

    /** @param  array<string, mixed>  $config */
    private function download(string $url, array $config): ?string
    {
        try {
            $response = Http::withHeaders([
                'Referer' => (string) $config['referer'],
                'User-Agent' => (string) $config['user_agent'],
            ])
                ->timeout((int) ($config['timeout'] ?? 45))
                ->retry(2, 1000, throw: false)
                ->get($url);
        } catch (ConnectionException) {
            return null;
        }

        return $response->successful() ? $response->body() : null;
    }
}
