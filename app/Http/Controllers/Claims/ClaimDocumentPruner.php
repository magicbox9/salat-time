<?php

namespace App\Http\Controllers\Claims;

use App\Models\MosqueClaim;
use Illuminate\Contracts\Filesystem\Filesystem;
use Illuminate\Support\Facades\Storage;

/**
 * Deletes supporting documents whose claim no longer exists. A claim row goes
 * away with its user or its mosque (ON DELETE CASCADE, so no model event
 * fires), and a failed submission can leave a file behind: without this,
 * personal documents would stay on the private disk forever.
 * Scheduled daily by AdminServiceProvider.
 */
class ClaimDocumentPruner
{
    /** Files younger than this may belong to a claim that is still being saved. */
    public const GRACE_SECONDS = 3600;

    /** Returns the number of claim folders removed. */
    public function __invoke(): int
    {
        $disk = Storage::disk('local');
        $ids = collect($disk->directories('claims'))
            ->map(fn (string $directory): string => basename($directory))
            ->filter(fn (string $name): bool => ctype_digit($name))
            ->map(fn (string $name): int => (int) $name)
            ->values();

        $removed = 0;
        foreach ($ids->chunk(500) as $chunk) {
            $existing = MosqueClaim::query()->whereKey($chunk->all())->pluck('id')->all();

            foreach (array_diff($chunk->all(), $existing) as $id) {
                $directory = 'claims/'.$id;
                if ($this->hasRecentFiles($disk, $directory)) {
                    continue;
                }
                $disk->deleteDirectory($directory);
                $removed++;
            }
        }

        return $removed;
    }

    private function hasRecentFiles(Filesystem $disk, string $directory): bool
    {
        $cutoff = now()->getTimestamp() - self::GRACE_SECONDS;

        foreach ($disk->allFiles($directory) as $file) {
            if ($disk->lastModified($file) > $cutoff) {
                return true;
            }
        }

        return false;
    }
}
