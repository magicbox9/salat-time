<?php

namespace Tests\Feature\MosqueSite;

use App\Models\Mosque;
use App\Models\MosquePage;
use App\Models\MosquePost;
use App\Models\MosquePostCategory;
use App\Models\User;

/** Small builders for a mosque's site: its manager, categories, posts and pages. */
trait BuildsMosqueSites
{
    protected function managerOf(Mosque $mosque, array $attributes = []): User
    {
        $user = User::factory()->create($attributes);
        $mosque->managers()->attach($user, ['role' => 'owner']);

        return $user;
    }

    protected function admin(): User
    {
        $admin = User::factory()->create();
        $admin->forceFill(['is_admin' => true])->save();

        return $admin;
    }

    protected function category(Mosque $mosque, string $name, string $slug, int $sort = 0): MosquePostCategory
    {
        return MosquePostCategory::query()->create([
            'mosque_id' => $mosque->id, 'name' => $name, 'slug' => $slug, 'sort' => $sort,
        ]);
    }

    protected function blogPost(Mosque $mosque, array $attributes = []): MosquePost
    {
        return MosquePost::factory()->for($mosque)->create([
            'slug' => 'post-'.fake()->unique()->numberBetween(1, 999999),
            'published_at' => now()->subHour(),
            ...$attributes,
        ]);
    }

    protected function sitePage(Mosque $mosque, array $attributes = []): MosquePage
    {
        return MosquePage::query()->create([
            'mosque_id' => $mosque->id,
            'title' => 'À propos',
            'slug' => 'a-propos',
            'body' => "## Notre histoire\n\nLa mosquée accueille les fidèles depuis 1987.",
            'sort' => 0,
            'show_in_menu' => true,
            'published_at' => now()->subDay(),
            ...$attributes,
        ]);
    }
}
