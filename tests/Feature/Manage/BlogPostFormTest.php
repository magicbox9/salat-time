<?php

namespace Tests\Feature\Manage;

use App\Models\Mosque;
use App\Models\MosquePost;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Storage;
use Inertia\Testing\AssertableInertia as Assert;
use Tests\Feature\MosqueSite\BuildsMosqueSites;
use Tests\TestCase;

/** The blog post form: address, category, schedule, khutbah video and PDF. */
class BlogPostFormTest extends TestCase
{
    use BuildsMosqueSites, RefreshDatabase;

    private const PDF = "%PDF-1.4\n1 0 obj << /Type /Catalog >> endobj\ntrailer << /Root 1 0 R >>\n%%EOF\n";

    private Mosque $mosque;

    private User $manager;

    protected function setUp(): void
    {
        parent::setUp();
        $this->withoutVite();
        Storage::fake('public');
        $this->mosque = Mosque::factory()->create(['timezone' => 'Europe/Paris']);
        $this->manager = $this->managerOf($this->mosque);
    }

    private function base(): string
    {
        return "/manage/{$this->mosque->slug}/posts";
    }

    /** @return array<string, mixed> */
    private function valid(array $overrides = []): array
    {
        return [
            'title' => 'La patience face aux épreuves',
            'body' => "## Introduction\n\nLouange à Allah.",
            'status' => 'published',
            ...$overrides,
        ];
    }

    public function test_a_post_gets_its_address_category_excerpt_and_video(): void
    {
        $khutbah = $this->category($this->mosque, 'Khutbah', 'khutbah');

        $this->actingAs($this->manager)->post($this->base(), $this->valid([
            'category_id' => $khutbah->id,
            'excerpt' => '  Un rappel sur la patience.  ',
            'video_url' => 'https://youtu.be/dQw4w9WgXcQ?si=tracking',
        ]))->assertRedirect($this->base())->assertSessionHasNoErrors();

        $post = MosquePost::query()->sole();
        $this->assertSame('la-patience-face-aux-epreuves', $post->slug);
        $this->assertSame($khutbah->id, $post->category_id);
        $this->assertSame('Un rappel sur la patience.', $post->excerpt);
        $this->assertSame('https://www.youtube.com/watch?v=dQw4w9WgXcQ', $post->video_url);
        $this->assertSame('news', $post->type);

        // Same title again: the next free address.
        $this->actingAs($this->manager)->post($this->base(), $this->valid())->assertSessionHasNoErrors();
        $this->assertSame('la-patience-face-aux-epreuves-2', MosquePost::query()->latest('id')->first()->slug);

        $this->get("/mosques/{$this->mosque->slug}/blog/la-patience-face-aux-epreuves")->assertOk();
    }

    public function test_chosen_addresses_are_checked_and_kept_when_left_empty(): void
    {
        $this->blogPost($this->mosque, ['slug' => 'deja-pris']);
        $this->blogPost(Mosque::factory()->create(), ['slug' => 'ailleurs']);

        $this->actingAs($this->manager)->post($this->base(), $this->valid(['slug' => 'deja-pris']))->assertSessionHasErrors('slug');
        $this->actingAs($this->manager)->post($this->base(), $this->valid(['slug' => 'Avec Espaces']))->assertSessionHasErrors('slug');
        $this->actingAs($this->manager)->post($this->base(), $this->valid(['slug' => '-tiret']))->assertSessionHasErrors('slug');
        $this->actingAs($this->manager)->post($this->base(), $this->valid(['slug' => 'ailleurs']))->assertSessionHasNoErrors();

        $post = MosquePost::query()->where('slug', 'ailleurs')->where('mosque_id', $this->mosque->id)->sole();
        $this->actingAs($this->manager)->put("{$this->base()}/{$post->id}", $this->valid(['slug' => '', 'title' => 'Nouveau titre']))
            ->assertSessionHasNoErrors();
        $this->assertSame('ailleurs', $post->fresh()->slug);
        $this->actingAs($this->manager)->put("{$this->base()}/{$post->id}", $this->valid(['slug' => 'ailleurs']))
            ->assertSessionHasNoErrors();
    }

    public function test_a_category_of_another_mosque_is_refused(): void
    {
        $foreign = $this->category(Mosque::factory()->create(), 'Ailleurs', 'ailleurs');

        $this->actingAs($this->manager)->post($this->base(), $this->valid(['category_id' => $foreign->id]))
            ->assertSessionHasErrors('category_id');
        $this->actingAs($this->manager)->post($this->base(), $this->valid(['category_id' => '99999999999999999999']))
            ->assertSessionHasErrors('category_id');
        $this->assertDatabaseCount('mosque_posts', 0);
    }

    public function test_only_youtube_and_vimeo_videos_are_accepted(): void
    {
        foreach (['https://evil.example/v.mp4', 'javascript:alert(1)', 'https://www.dailymotion.com/video/x7tgad0'] as $url) {
            $this->actingAs($this->manager)->post($this->base(), $this->valid(['video_url' => $url]))
                ->assertSessionHasErrors('video_url');
        }

        $this->actingAs($this->manager)->post($this->base(), $this->valid(['video_url' => 'https://vimeo.com/76979871']))
            ->assertSessionHasNoErrors();
        $this->assertSame('https://vimeo.com/76979871', MosquePost::query()->sole()->video_url);
    }

    public function test_posts_are_scheduled_in_the_mosque_s_time_zone(): void
    {
        $at = now('Europe/Paris')->addDays(2)->setTime(18, 30);

        $this->actingAs($this->manager)->post($this->base(), $this->valid(['status' => 'scheduled']))
            ->assertSessionHasErrors('publish_at');
        $this->actingAs($this->manager)->post($this->base(), $this->valid([
            'status' => 'scheduled', 'publish_at' => now('Europe/Paris')->subHour()->format('Y-m-d\TH:i'),
        ]))->assertSessionHasErrors('publish_at');

        $this->actingAs($this->manager)->post($this->base(), $this->valid([
            'status' => 'scheduled', 'publish_at' => $at->format('Y-m-d\TH:i'),
        ]))->assertSessionHasNoErrors();

        $post = MosquePost::query()->sole();
        $this->assertSame($at->utc()->format('Y-m-d H:i'), $post->published_at->utc()->format('Y-m-d H:i'));

        $this->app['auth']->forgetGuards();
        $this->get("/mosques/{$this->mosque->slug}/blog/{$post->slug}")->assertNotFound();

        $this->travelTo($at->addMinute());
        $this->get("/mosques/{$this->mosque->slug}/blog/{$post->slug}")->assertOk();
        $this->travelBack();

        $this->actingAs($this->manager)->get("{$this->base()}?status=scheduled")
            ->assertInertia(fn (Assert $page) => $page->has('posts.data', 1)->where('posts.data.0.status', 'scheduled'));
        $this->actingAs($this->manager)->get("{$this->base()}/{$post->id}/edit")
            ->assertInertia(fn (Assert $page) => $page
                ->where('post.status', 'scheduled')
                ->where('post.publish_at', $at->format('Y-m-d\TH:i')));

        // Publishing it now brings the date to now; publishing again keeps that date.
        $this->actingAs($this->manager)->put("{$this->base()}/{$post->id}", $this->valid(['status' => 'published']));
        $published = $post->fresh()->published_at;
        $this->assertFalse($published->isFuture());
        $this->travel(5)->minutes();
        $this->actingAs($this->manager)->put("{$this->base()}/{$post->id}", $this->valid(['status' => 'published']));
        $this->assertTrue($published->equalTo($post->fresh()->published_at));
    }

    public function test_a_pdf_is_stored_under_the_mosque_with_a_safe_name(): void
    {
        $file = UploadedFile::fake()->createWithContent('../../Khutbah du 12 <octobre>.PDF', self::PDF);

        $this->actingAs($this->manager)->post($this->base(), $this->valid(['attachment' => $file]))
            ->assertSessionHasNoErrors();

        $post = MosquePost::query()->sole();
        $this->assertMatchesRegularExpression(
            '#^mosques/'.$this->mosque->id.'/files/khutbah-du-12-octobre-[a-z0-9]{12}\.pdf$#',
            $post->attachment_path,
        );
        $this->assertSame('Khutbah du 12 octobre.pdf', $post->attachment_name);
        Storage::disk('public')->assertExists($post->attachment_path);

        $this->get("/mosques/{$this->mosque->slug}/blog/{$post->slug}")
            ->assertInertia(fn (Assert $page) => $page
                ->where('post.attachment.name', 'Khutbah du 12 octobre.pdf')
                ->where('post.attachment.size', strlen(self::PDF)));

        // Replaced, then removed: the old files go.
        $first = $post->attachment_path;
        $this->actingAs($this->manager)->put("{$this->base()}/{$post->id}", $this->valid([
            'attachment' => UploadedFile::fake()->createWithContent('programme.pdf', self::PDF),
        ]))->assertSessionHasNoErrors();
        Storage::disk('public')->assertMissing($first);
        $second = $post->fresh()->attachment_path;
        Storage::disk('public')->assertExists($second);

        $this->actingAs($this->manager)->put("{$this->base()}/{$post->id}", $this->valid(['remove_attachment' => true]));
        $this->assertNull($post->fresh()->attachment_path);
        $this->assertNull($post->fresh()->attachment_name);
        Storage::disk('public')->assertMissing($second);
    }

    public function test_only_real_pdfs_of_ten_megabytes_at_most_are_accepted(): void
    {
        $cases = [
            UploadedFile::fake()->create('notes.txt', 10, 'text/plain'),
            UploadedFile::fake()->createWithContent('page.html', '<script>alert(1)</script>'),
            UploadedFile::fake()->create('huge.pdf', 10241, 'application/pdf'),
        ];

        foreach ($cases as $file) {
            $this->actingAs($this->manager)->post($this->base(), $this->valid(['attachment' => $file]))
                ->assertSessionHasErrors('attachment');
        }

        // Claims to be a PDF, is not one.
        $this->actingAs($this->manager)->post($this->base(), $this->valid([
            'attachment' => UploadedFile::fake()->createWithContent('fake.pdf', 'MZ not a pdf at all'),
        ]))->assertSessionHasErrors('attachment');

        $this->assertDatabaseCount('mosque_posts', 0);
        $this->assertSame([], Storage::disk('public')->allFiles());
    }

    public function test_deleting_a_post_removes_its_files_and_frees_its_address(): void
    {
        $this->actingAs($this->manager)->post($this->base(), $this->valid([
            'image' => UploadedFile::fake()->image('cover.jpg', 800, 400),
            'attachment' => UploadedFile::fake()->createWithContent('texte.pdf', self::PDF),
        ]))->assertSessionHasNoErrors();
        $post = MosquePost::query()->sole();
        [$image, $pdf] = [$post->image_path, $post->attachment_path];

        $this->actingAs($this->manager)->delete("{$this->base()}/{$post->id}")->assertRedirect($this->base());

        $this->assertSoftDeleted($post);
        Storage::disk('public')->assertMissing($image);
        Storage::disk('public')->assertMissing($pdf);

        $this->actingAs($this->manager)->post($this->base(), $this->valid(['slug' => $post->slug]))->assertSessionHasNoErrors();
    }

    public function test_the_form_offers_the_mosque_s_categories(): void
    {
        $this->mosque->forceFill(['post_categories_seeded_at' => now()])->save();
        $this->category($this->mosque, 'Khutbah', 'khutbah');
        $this->category(Mosque::factory()->create(), 'Ailleurs', 'ailleurs');

        $this->actingAs($this->manager)->get("{$this->base()}/create")
            ->assertInertia(fn (Assert $page) => $page
                ->component('manage/post-form')
                ->has('categories', 1)
                ->where('categories.0.slug', 'khutbah')
                ->where('limits.attachment_mb', 10));
    }
}
