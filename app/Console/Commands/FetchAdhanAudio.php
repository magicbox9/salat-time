<?php

namespace App\Console\Commands;

use App\Services\Display\AdhanCatalog;
use App\Services\Display\DisplayMediaStore;
use Illuminate\Console\Command;
use Illuminate\Http\Client\ConnectionException;
use Illuminate\Support\Facades\Http;
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

        $this->newLine();
        $this->line('Reminder: clear the rights to these recordings with their publisher before a public launch.');

        return $failed === 0 ? self::SUCCESS : self::FAILURE;
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
