<?php

namespace Tests\Feature\Manage;

use App\Models\Mosque;
use App\Models\MosquePage;
use App\Models\MosquePost;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Tests\Feature\MosqueSite\BuildsMosqueSites;
use Tests\TestCase;

/**
 * Two managers saving at the same moment: the address checked by validation
 * is taken by the other request just before the insert. The later save takes
 * the next automatic address, or goes back to the form, never a server error.
 */
class SlugRaceTest extends TestCase
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

    /**
     * Another request saves a row with $slug after this request validated and
     * picked its address, just before its insert (and outside its savepoint).
     */
    private function raceBeforeSaving(string $table, string $slug, array $row): void
    {
        $raced = false;
        DB::connection()->beforeStartingTransaction(function () use (&$raced, $table, $slug, $row): void {
            if (! $raced) {
                $raced = true;
                DB::table($table)->insert([...$row, 'mosque_id' => $this->mosque->id, 'slug' => $slug,
                    'created_at' => now(), 'updated_at' => now()]);
            }
        });
    }

    public function test_a_post_s_automatic_address_moves_on_when_taken_meanwhile(): void
    {
        $this->raceBeforeSaving('mosque_posts', 'cours-du-samedi', ['title' => 'Autre', 'body' => 'x', 'type' => 'news']);

        $this->actingAs($this->manager)
            ->post("/manage/{$this->mosque->slug}/posts", ['title' => 'Cours du samedi', 'body' => 'Texte', 'status' => 'published'])
            ->assertSessionHasNoErrors()
            ->assertRedirect("/manage/{$this->mosque->slug}/posts");

        $this->assertSame(
            ['cours-du-samedi', 'cours-du-samedi-2'],
            MosquePost::query()->orderBy('id')->pluck('slug')->all(),
        );
        $this->assertSame('Cours du samedi', MosquePost::query()->where('slug', 'cours-du-samedi-2')->value('title'));
    }

    public function test_a_post_s_chosen_address_taken_meanwhile_goes_back_to_the_form(): void
    {
        $this->raceBeforeSaving('mosque_posts', 'cours', ['title' => 'Autre', 'body' => 'x', 'type' => 'news']);

        $this->actingAs($this->manager)
            ->from("/manage/{$this->mosque->slug}/posts/create")
            ->post("/manage/{$this->mosque->slug}/posts", [
                'title' => 'Cours du samedi', 'slug' => 'cours', 'body' => 'Texte', 'status' => 'published',
            ])
            ->assertRedirect("/manage/{$this->mosque->slug}/posts/create")
            ->assertSessionHasErrors(['slug' => ui('manage.slug_taken')]);
    }

    public function test_a_page_s_automatic_address_moves_on_when_taken_meanwhile(): void
    {
        $this->raceBeforeSaving('mosque_pages', 'horaires', ['title' => 'Autre', 'body' => 'x']);

        $this->actingAs($this->manager)
            ->post("/manage/{$this->mosque->slug}/pages", ['title' => 'Horaires', 'body' => 'Texte', 'published' => true])
            ->assertSessionHasNoErrors()
            ->assertRedirect("/manage/{$this->mosque->slug}/pages");

        $this->assertSame(['horaires', 'horaires-2'], MosquePage::query()->orderBy('id')->pluck('slug')->all());
    }

    public function test_a_page_s_chosen_address_taken_meanwhile_goes_back_to_the_form(): void
    {
        $this->raceBeforeSaving('mosque_pages', 'horaires-du-centre', ['title' => 'Autre', 'body' => 'x']);

        $this->actingAs($this->manager)
            ->from("/manage/{$this->mosque->slug}/pages/create")
            ->post("/manage/{$this->mosque->slug}/pages", [
                'title' => 'Horaires', 'slug' => 'horaires-du-centre', 'body' => 'Texte', 'published' => true,
            ])
            ->assertRedirect("/manage/{$this->mosque->slug}/pages/create")
            ->assertSessionHasErrors(['slug' => ui('manage.slug_taken')]);
    }
}
