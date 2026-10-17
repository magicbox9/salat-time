<?php

namespace Tests\Feature\Manage;

use App\Models\Mosque;
use App\Models\MosquePage;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Inertia\Testing\AssertableInertia as Assert;
use Tests\Feature\MosqueSite\BuildsMosqueSites;
use Tests\TestCase;

class PageManagementTest extends TestCase
{
    use BuildsMosqueSites, RefreshDatabase;

    private Mosque $mosque;

    private User $manager;

    protected function setUp(): void
    {
        parent::setUp();
        $this->withoutVite();
        $this->mosque = Mosque::factory()->create();
        $this->manager = $this->managerOf($this->mosque);
    }

    private function base(): string
    {
        return "/manage/{$this->mosque->slug}/pages";
    }

    /** @return array<string, mixed> */
    private function valid(array $overrides = []): array
    {
        return [
            'title' => 'Nos cours',
            'slug' => '',
            'body' => "## Arabe\n\nLe samedi matin.",
            'sort' => 2,
            'show_in_menu' => true,
            'published' => true,
            ...$overrides,
        ];
    }

    public function test_managers_create_a_page_that_appears_in_the_menu(): void
    {
        $this->actingAs($this->manager)->post($this->base(), $this->valid())
            ->assertRedirect($this->base())
            ->assertSessionHasNoErrors();

        $page = MosquePage::query()->sole();
        $this->assertSame('nos-cours', $page->slug);
        $this->assertSame($this->manager->id, $page->author_id);
        $this->assertNotNull($page->published_at);

        $this->get("/mosques/{$this->mosque->slug}")
            ->assertInertia(fn (Assert $p) => $p->where('site.menu', [['title' => 'Nos cours', 'slug' => 'nos-cours']]));
        $this->get("/mosques/{$this->mosque->slug}/pages/nos-cours")->assertOk();
    }

    public function test_slugs_are_unique_and_chosen_slugs_are_checked(): void
    {
        $this->actingAs($this->manager)->post($this->base(), $this->valid());
        $this->actingAs($this->manager)->post($this->base(), $this->valid());
        $this->assertSame(['nos-cours', 'nos-cours-2'], MosquePage::query()->orderBy('id')->pluck('slug')->all());

        $this->actingAs($this->manager)->post($this->base(), $this->valid(['slug' => 'nos-cours']))->assertSessionHasErrors('slug');
        $this->actingAs($this->manager)->post($this->base(), $this->valid(['slug' => 'Pas Valide']))->assertSessionHasErrors('slug');
        $this->actingAs($this->manager)->post($this->base(), $this->valid(['slug' => 'contact']))->assertSessionHasNoErrors();
        $this->assertDatabaseHas('mosque_pages', ['slug' => 'contact']);

        // Another mosque may use the same address.
        $other = Mosque::factory()->create();
        $this->actingAs($this->admin())->post("/manage/{$other->slug}/pages", $this->valid(['slug' => 'contact']))
            ->assertSessionHasNoErrors();
    }

    public function test_managers_edit_unpublish_and_delete_pages(): void
    {
        $page = $this->sitePage($this->mosque, ['slug' => 'a-propos']);

        $this->actingAs($this->manager)->get("{$this->base()}/{$page->id}/edit")
            ->assertInertia(fn (Assert $p) => $p->component('manage/page-form')->where('page.slug', 'a-propos'));

        $this->actingAs($this->manager)->put("{$this->base()}/{$page->id}", $this->valid([
            'title' => 'Qui sommes-nous', 'slug' => 'a-propos', 'published' => false, 'show_in_menu' => false,
        ]))->assertSessionHasNoErrors();
        $page->refresh();
        $this->assertSame('Qui sommes-nous', $page->title);
        $this->assertNull($page->published_at);
        $this->assertFalse($page->show_in_menu);
        $this->app['auth']->forgetGuards();
        $this->get("/mosques/{$this->mosque->slug}/pages/a-propos")->assertNotFound();

        $this->actingAs($this->manager)->delete("{$this->base()}/{$page->id}")->assertRedirect($this->base());
        $this->assertSoftDeleted($page);

        // Its address is free again.
        $this->actingAs($this->manager)->post($this->base(), $this->valid(['slug' => 'a-propos']))->assertSessionHasNoErrors();
    }

    public function test_pages_are_validated(): void
    {
        $this->actingAs($this->manager)->post($this->base(), [
            'title' => '',
            'body' => str_repeat('b', 50001),
            'sort' => 1000,
            'slug' => str_repeat('s', 161),
        ])->assertSessionHasErrors(['title', 'body', 'sort', 'slug']);
        $this->actingAs($this->manager)->post($this->base(), $this->valid(['body' => "x\0y"]))->assertSessionHasErrors('body');

        $this->assertDatabaseCount('mosque_pages', 0);
    }

    public function test_only_the_mosque_s_managers_manage_its_pages(): void
    {
        $page = $this->sitePage($this->mosque);
        $foreign = $this->sitePage(Mosque::factory()->create());
        $stranger = $this->managerOf(Mosque::factory()->create());

        $this->get($this->base())->assertRedirect('/login');
        $this->actingAs($stranger)->get($this->base())->assertForbidden();
        $this->actingAs($stranger)->post($this->base(), $this->valid())->assertForbidden();
        $this->actingAs($stranger)->put("{$this->base()}/{$page->id}", $this->valid())->assertForbidden();
        $this->actingAs($stranger)->delete("{$this->base()}/{$page->id}")->assertForbidden();

        $this->actingAs($this->manager)->get("{$this->base()}/{$foreign->id}/edit")->assertNotFound();
        $this->actingAs($this->manager)->put("{$this->base()}/{$foreign->id}", $this->valid())->assertNotFound();
        $this->actingAs($this->manager)->delete("{$this->base()}/{$foreign->id}")->assertNotFound();
        $this->actingAs($this->manager)->get("{$this->base()}/99999999999999999999/edit")->assertNotFound();

        $this->assertNotSoftDeleted($foreign);
        $this->assertSame('À propos', $page->fresh()->title);
    }
}
