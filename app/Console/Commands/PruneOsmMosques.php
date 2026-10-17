<?php

namespace App\Console\Commands;

use App\Models\Mosque;
use App\Support\OsmPlaceOfWorship;
use Illuminate\Console\Attributes\Description;
use Illuminate\Console\Attributes\Signature;
use Illuminate\Console\Command;

/**
 * Removes the OpenStreetMap records imported before mosques:import learned
 * to skip shops, funeral directors, schools and cemetery plots
 * (OsmPlaceOfWorship). A record someone has already worked on (a manager, a
 * claim, a post or a campaign) is kept and listed for an admin to review.
 */
#[Signature('mosques:prune-osm
    {--path=/data/studies : Folder that holds "study 1"}
    {--dry-run : List what would be removed without removing it}')]
#[Description('Remove imported OpenStreetMap places that are not mosques (shops, funeral directors, schools…)')]
class PruneOsmMosques extends Command
{
    public function handle(): int
    {
        $path = rtrim((string) $this->option('path'), '/').'/study 1/data/osm_mosques_france.json';
        if (! is_file($path)) {
            $this->error("OpenStreetMap list not found at $path (is STUDIES_PATH mounted?)");

            return self::FAILURE;
        }

        $rejected = [];
        foreach (json_decode((string) file_get_contents($path), true) ?: [] as $place) {
            if (isset($place['osm']) && ! OsmPlaceOfWorship::accepts($place['tags'] ?? [])) {
                $rejected[] = (string) $place['osm'];
            }
        }

        $removed = 0;
        $kept = [];
        Mosque::query()
            ->where('source', 'osm')
            ->whereIn('osm_ref', $rejected)
            ->withCount(['managers', 'claims', 'posts', 'campaigns'])
            ->orderBy('name')
            ->each(function (Mosque $mosque) use (&$removed, &$kept) {
                $inUse = $mosque->managers_count + $mosque->claims_count + $mosque->posts_count + $mosque->campaigns_count > 0;
                if ($inUse) {
                    $kept[] = "{$mosque->name} ({$mosque->slug})";

                    return;
                }
                $this->line(($this->option('dry-run') ? 'Would remove: ' : 'Removed: ')."{$mosque->name} ({$mosque->slug}, {$mosque->osm_ref})");
                if (! $this->option('dry-run')) {
                    $mosque->delete();
                }
                $removed++;
            });

        $this->info(($this->option('dry-run') ? 'Would remove ' : 'Removed ')."$removed OpenStreetMap places that are not mosques.");
        if ($kept) {
            $this->warn('Kept for review (managers, claims, posts or campaigns): '.implode(', ', $kept));
        }

        return self::SUCCESS;
    }
}
