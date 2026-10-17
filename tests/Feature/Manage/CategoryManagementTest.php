<?php

namespace Tests\Feature\Manage;

use App\Models\Mosque;
use App\Models\MosquePostCategory;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Inertia\Testing\AssertableInertia as Assert;
use Tests\Feature\MosqueSite\BuildsMosqueSites;
use Tests\TestCase;

class CategoryManagementTest extends TestCase
{
    use BuildsMosqueSites, RefreshDatabase;

    private Mosque $mosque;

    private User $manager;

    protected function setUp(): void
    {
        parent::setUp();
        $this->withoutVite();
        $this->mosque = Mosque::factory()->create();
        $this->manager = $this->managerOf($this->mosque, ['locale' => 'fr']);
    }

    private function base(): string
    {
        return "/manage/{$this->mosque->slug}/categories";
    }

    public function test_the_default_categories_are_created_once_in_the_manager_s_language(): void
    {
        $this->actingAs($this->manager)->get($this->base())
            ->assertOk()
            ->assertInertia(fn (Assert $page) => $page
                ->component('manage/categories')
                ->has('categories', 5)
                ->where('categories.0.slug', 'khutbah')
                ->where('categories.1.name', 'Actualités')
                ->where('categories.4.name', 'Annonces'));

        $this->assertNotNull($this->mosque->fresh()->getAttribute('post_categories_seeded_at'));

        // Deleted defaults do not come back.
        MosquePostCategory::query()->where('mosque_id', $this->mosque->id)->delete();
        $this->actingAs($this->manager)->get($this->base())
            ->assertInertia(fn (Assert $page) => $page->has('categories', 0));
        $this->actingAs($this->manager)->get("/manage/{$this->mosque->slug}/posts/create")->assertOk();
        $this->assertSame(0, MosquePostCategory::query()->count());
    }

    public function test_a_mosque_with_categories_keeps_them(): void
    {
        $this->category($this->mosque, 'Cours', 'cours');

        $this->actingAs($this->manager)->get("/manage/{$this->mosque->slug}")->assertOk();

        $this->assertSame(['cours'], MosquePostCategory::query()->pluck('slug')->all());
    }

    public function test_managers_create_rename_and_reorder_categories(): void
    {
        $this->mosque->forceFill(['post_categories_seeded_at' => now()])->save();
        $first = $this->category($this->mosque, 'Khutbah', 'khutbah', 0);

        $this->actingAs($this->manager)->from($this->base())
            ->post($this->base(), ['name' => 'Cours d’arabe', 'description' => 'Pour adultes et enfants'])
            ->assertRedirect($this->base())
            ->assertSessionHasNoErrors();
        $created = MosquePostCategory::query()->where('name', 'Cours d’arabe')->sole();
        $this->assertSame('cours-darabe', $created->slug);
        $this->assertSame(1, $created->sort);

        $this->actingAs($this->manager)->post($this->base(), ['name' => 'cours d’arabe'])->assertSessionHasNoErrors();
        $this->actingAs($this->manager)->post($this->base(), ['name' => 'Cours d’arabe'])->assertSessionHasErrors('name');

        $this->actingAs($this->manager)->put("{$this->base()}/{$first->id}", ['name' => 'Sermons du vendredi'])
            ->assertSessionHasNoErrors();
        $this->assertSame('Sermons du vendredi', $first->fresh()->name);
        $this->assertSame('khutbah', $first->fresh()->slug);

        $ids = MosquePostCategory::query()->orderBy('sort')->pluck('id')->reverse()->values()->all();
        $this->actingAs($this->manager)->put("{$this->base()}/order", ['ids' => $ids])->assertSessionHasNoErrors();
        $this->assertSame($ids, MosquePostCategory::query()->orderBy('sort')->pluck('id')->all());
    }

    public function test_reordering_needs_exactly_the_mosque_s_own_categories(): void
    {
        $mine = $this->category($this->mosque, 'A', 'a');
        $theirs = $this->category(Mosque::factory()->create(), 'B', 'b');

        $this->actingAs($this->manager)->put("{$this->base()}/order", ['ids' => [$mine->id, $theirs->id]])
            ->assertSessionHasErrors('ids');
        $this->actingAs($this->manager)->put("{$this->base()}/order", ['ids' => []])->assertSessionHasErrors('ids');
        $this->actingAs($this->manager)->put("{$this->base()}/order", ['ids' => ['x']])->assertSessionHasErrors('ids.0');
    }

    public function test_deleting_a_category_keeps_its_posts_uncategorised(): void
    {
        $category = $this->category($this->mosque, 'Événements', 'events');
        $post = $this->blogPost($this->mosque, ['category_id' => $category->id]);
        $trashed = $this->blogPost($this->mosque, ['category_id' => $category->id]);
        $trashed->delete();

        $this->actingAs($this->manager)->delete("{$this->base()}/{$category->id}")->assertSessionHasNoErrors();

        $this->assertModelMissing($category);
        $this->assertNotSoftDeleted($post);
        $this->assertNull($post->fresh()->category_id);
        $this->assertNull($trashed->fresh()->category_id);
    }

    public function test_categories_are_validated_and_limited(): void
    {
        $this->actingAs($this->manager)->post($this->base(), ['name' => 'x'])->assertSessionHasErrors('name');
        $this->actingAs($this->manager)->post($this->base(), ['name' => str_repeat('n', 81)])->assertSessionHasErrors('name');
        $this->actingAs($this->manager)->post($this->base(), ['name' => "Bad\0name"])->assertSessionHasErrors('name');

        foreach (range(1, 30) as $i) {
            $this->category($this->mosque, "C$i", "c$i");
        }
        $this->actingAs($this->manager)->post($this->base(), ['name' => 'Une de trop'])->assertSessionHasErrors('name');
    }

    public function test_only_the_mosque_s_managers_touch_its_categories(): void
    {
        $category = $this->category($this->mosque, 'Khutbah', 'khutbah');
        $foreign = $this->category(Mosque::factory()->create(), 'Ailleurs', 'ailleurs');
        $stranger = $this->managerOf(Mosque::factory()->create());

        $this->get($this->base())->assertRedirect('/login');
        $this->actingAs($stranger)->get($this->base())->assertForbidden();
        $this->actingAs($stranger)->post($this->base(), ['name' => 'Piratage'])->assertForbidden();
        $this->actingAs($stranger)->put("{$this->base()}/{$category->id}", ['name' => 'Piratage'])->assertForbidden();
        $this->actingAs($stranger)->delete("{$this->base()}/{$category->id}")->assertForbidden();

        // A category of another mosque cannot be reached through this one.
        $this->actingAs($this->manager)->put("{$this->base()}/{$foreign->id}", ['name' => 'Piratage'])->assertNotFound();
        $this->actingAs($this->manager)->delete("{$this->base()}/{$foreign->id}")->assertNotFound();

        $this->assertSame('Khutbah', $category->fresh()->name);
        $this->assertSame('Ailleurs', $foreign->fresh()->name);

        $this->actingAs($this->admin())->put("{$this->base()}/{$category->id}", ['name' => 'Khutbas'])->assertSessionHasNoErrors();
        $this->assertSame('Khutbas', $category->fresh()->name);
    }
}
