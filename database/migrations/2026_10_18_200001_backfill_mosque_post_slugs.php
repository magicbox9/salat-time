<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;

/**
 * Every live post gets an address on its mosque's blog: a slug made from its
 * title, unique within the mosque (soft-deleted posts keep theirs, so they
 * are counted too). Written with the query builder so later model changes
 * cannot alter what this migration does.
 */
return new class extends Migration
{
    private const MAX = 200;

    public function up(): void
    {
        $mosqueIds = DB::table('mosque_posts')
            ->whereNull('slug')
            ->whereNull('deleted_at')
            ->distinct()
            ->orderBy('mosque_id')
            ->pluck('mosque_id');

        foreach ($mosqueIds as $mosqueId) {
            DB::transaction(function () use ($mosqueId): void {
                $taken = DB::table('mosque_posts')
                    ->where('mosque_id', $mosqueId)
                    ->whereNotNull('slug')
                    ->pluck('slug')
                    ->flip()
                    ->all();

                $posts = DB::table('mosque_posts')
                    ->where('mosque_id', $mosqueId)
                    ->whereNull('slug')
                    ->whereNull('deleted_at')
                    ->orderBy('id')
                    ->get(['id', 'title']);

                foreach ($posts as $post) {
                    $slug = $this->free($this->base((string) $post->title), $taken);
                    $taken[$slug] = true;
                    DB::table('mosque_posts')->where('id', $post->id)->update(['slug' => $slug]);
                }
            });
        }
    }

    public function down(): void
    {
        // Slugs are harmless to keep: nothing to undo.
    }

    private function base(string $title): string
    {
        $slug = trim(substr(Str::slug($title), 0, self::MAX), '-');

        return $slug !== '' ? $slug : 'post';
    }

    /** @param  array<string, mixed>  $taken */
    private function free(string $base, array $taken): string
    {
        if (! isset($taken[$base])) {
            return $base;
        }

        for ($i = 2; ; $i++) {
            $suffix = '-'.$i;
            $candidate = rtrim(substr($base, 0, self::MAX - strlen($suffix)), '-').$suffix;
            if (! isset($taken[$candidate])) {
                return $candidate;
            }
        }
    }
};
