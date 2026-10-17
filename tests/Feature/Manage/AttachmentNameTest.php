<?php

namespace Tests\Feature\Manage;

use App\Http\Controllers\Manage\Support\AttachmentStore;
use App\Models\Mosque;
use App\Models\MosquePost;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Storage;
use Tests\Feature\MosqueSite\BuildsMosqueSites;
use Tests\TestCase;

/** The name visitors see on a post's PDF cannot pretend to be another kind of file. */
class AttachmentNameTest extends TestCase
{
    use BuildsMosqueSites, RefreshDatabase;

    public function test_bidirectional_controls_are_removed_from_the_shown_name(): void
    {
        $this->assertSame('khutbafdp.exe.pdf', AttachmentStore::displayName("khutba\u{202E}fdp.exe.pdf"));
        $this->assertSame('Programme.pdf', AttachmentStore::displayName("\u{2067}Programme\u{2069}.PDF"));
        $this->assertSame('خطبة الجمعة.pdf', AttachmentStore::displayName("\u{200F}خطبة الجمعة.pdf"));
        // Joiners that Arabic and Persian names need are kept.
        $this->assertSame("می\u{200C}خواهم.pdf", AttachmentStore::displayName("می\u{200C}خواهم.pdf"));
    }

    public function test_an_uploaded_pdf_keeps_a_clean_name(): void
    {
        Storage::fake('public');
        $this->withoutVite();
        $mosque = Mosque::factory()->create();
        $manager = $this->managerOf($mosque);
        $pdf = UploadedFile::fake()->createWithContent("programme\u{202E}fdp.exe.pdf", "%PDF-1.4\n%%EOF\n");

        $this->actingAs($manager)->post("/manage/{$mosque->slug}/posts", [
            'title' => 'Programme du mois', 'body' => 'Ci-joint.', 'status' => 'published', 'attachment' => $pdf,
        ])->assertSessionHasNoErrors();

        $post = MosquePost::query()->sole();
        $this->assertSame('programmefdp.exe.pdf', $post->attachment_name);
        $this->assertMatchesRegularExpression("#^mosques/{$mosque->id}/files/[a-z0-9-]+-[a-z0-9]{12}\\.pdf$#", (string) $post->attachment_path);
        Storage::disk('public')->assertExists((string) $post->attachment_path);
    }
}
