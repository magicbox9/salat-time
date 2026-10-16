<?php

namespace Tests\Feature\Claims;

use App\Http\Controllers\Claims\ClaimDocumentPruner;
use App\Models\MosqueClaim;
use App\Providers\AdminServiceProvider;
use Illuminate\Console\Scheduling\Event;
use Illuminate\Console\Scheduling\Schedule;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Storage;
use Tests\TestCase;

/** Supporting documents never outlive their claim (deleted with its user or mosque). */
class ClaimDocumentPruneTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        Storage::fake('local');
    }

    public function test_documents_of_deleted_claims_are_removed(): void
    {
        $kept = MosqueClaim::factory()->create(['document_path' => 'claims/1/a.pdf']);
        $kept->forceFill(['document_path' => 'claims/'.$kept->id.'/a.pdf'])->save();
        Storage::disk('local')->put($kept->document_path, 'kept');

        $deleted = MosqueClaim::factory()->create();
        $orphan = 'claims/'.$deleted->id.'/b.pdf';
        Storage::disk('local')->put($orphan, 'secret');
        // The claimant deletes their account: the row goes by ON DELETE CASCADE.
        $deleted->user->delete();
        $this->assertModelMissing($deleted);

        $this->travel(2)->hours();

        $this->assertSame(1, (new ClaimDocumentPruner)());
        Storage::disk('local')->assertMissing($orphan);
        Storage::disk('local')->assertMissing('claims/'.$deleted->id);
        Storage::disk('local')->assertExists($kept->document_path);
    }

    public function test_recent_files_are_kept_while_a_claim_may_still_be_saving(): void
    {
        Storage::disk('local')->put('claims/999999/new.pdf', 'uploading');

        $this->assertSame(0, (new ClaimDocumentPruner)());
        Storage::disk('local')->assertExists('claims/999999/new.pdf');

        $this->travel(2)->hours();
        $this->assertSame(1, (new ClaimDocumentPruner)());
        Storage::disk('local')->assertMissing('claims/999999/new.pdf');
    }

    public function test_unexpected_folders_are_left_alone(): void
    {
        Storage::disk('local')->put('claims/not-a-claim/file.pdf', 'x');
        $this->travel(2)->hours();

        $this->assertSame(0, (new ClaimDocumentPruner)());
        Storage::disk('local')->assertExists('claims/not-a-claim/file.pdf');
    }

    public function test_the_cleanup_is_scheduled_daily(): void
    {
        $events = collect(app(Schedule::class)->events())
            ->filter(fn (Event $event) => $event->description === AdminServiceProvider::PRUNE_DOCUMENTS_TASK);

        $this->assertCount(1, $events);
        $this->assertSame('0 0 * * *', $events->first()->expression);
    }
}
