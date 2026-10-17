<?php

namespace Tests\Feature\Manage;

use App\Models\Mosque;
use App\Models\MosquePostCategory;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Inertia\Testing\AssertableInertia as Assert;
use Tests\Feature\MosqueSite\BuildsMosqueSites;
use Tests\TestCase;

/** The default blog categories are named in the language of the mosque's own manager. */
class DefaultCategoriesTest extends TestCase
{
    use BuildsMosqueSites, RefreshDatabase;

    public function test_an_admin_looking_around_does_not_create_them(): void
    {
        $this->withoutVite();
        $mosque = Mosque::factory()->create();
        $admin = $this->admin();
        $admin->forceFill(['locale' => 'en'])->save();
        $base = "/manage/{$mosque->slug}";

        foreach (['', '/posts', '/posts/create', '/categories'] as $path) {
            $this->actingAs($admin)->get($base.$path)->assertOk();
        }
        $this->assertSame(0, MosquePostCategory::query()->count());
        $this->assertNull($mosque->fresh()->getAttribute('post_categories_seeded_at'));

        // The mosque's manager, in Arabic, gets them in Arabic.
        $manager = $this->managerOf($mosque, ['locale' => 'ar']);
        $this->actingAs($manager)->get("$base/categories")
            ->assertInertia(fn (Assert $page) => $page
                ->has('categories', 5)
                ->where('categories.0.slug', 'khutbah')
                ->where('categories.0.name', 'خطب الجمعة'));
    }

    public function test_an_admin_who_also_manages_the_mosque_gets_them(): void
    {
        $this->withoutVite();
        $mosque = Mosque::factory()->create();
        $admin = $this->admin();
        $mosque->managers()->attach($admin, ['role' => 'owner']);

        $this->actingAs($admin)->get("/manage/{$mosque->slug}/posts/create")
            ->assertOk()
            ->assertInertia(fn (Assert $page) => $page->has('categories', 5));
    }
}
