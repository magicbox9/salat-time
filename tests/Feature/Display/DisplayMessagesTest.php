<?php

namespace Tests\Feature\Display;

use App\Models\Mosque;
use App\Models\MosqueDisplayMessage;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Inertia\Testing\AssertableInertia as Assert;
use Tests\TestCase;

class DisplayMessagesTest extends TestCase
{
    use DisplayFixtures, RefreshDatabase;

    private Mosque $mosque;

    private User $manager;

    private string $base;

    protected function setUp(): void
    {
        parent::setUp();
        $this->withoutVite();
        $this->mosque = $this->mosque();
        $this->manager = $this->managerOf($this->mosque);
        $this->base = "/manage/{$this->mosque->slug}/display/messages";
    }

    public function test_managers_write_messages_with_dates_in_the_mosques_time_zone(): void
    {
        $this->actingAs($this->manager)->post($this->base, [
            'body' => "  Lesson after Isha\u{0007}  ",
            'starts_at' => '2026-12-01T18:00',
            'ends_at' => '2026-12-02T21:30',
        ])->assertRedirect()->assertSessionHasNoErrors();

        $message = MosqueDisplayMessage::query()->sole();
        $this->assertSame('Lesson after Isha', $message->body);
        $this->assertSame('2026-12-01 17:00:00', $message->starts_at->utc()->format('Y-m-d H:i:s'));   // Paris is UTC+1 in December
        $this->assertTrue($message->active);

        $this->actingAs($this->manager)->get("/manage/{$this->mosque->slug}/display")
            ->assertInertia(fn (Assert $page) => $page
                ->where('messages.0.starts_at', '2026-12-01T18:00')
                ->where('messages.0.state', 'scheduled'));
    }

    public function test_messages_are_validated(): void
    {
        $this->actingAs($this->manager)->post($this->base, ['body' => ''])->assertSessionHasErrors('body');
        $this->actingAs($this->manager)->post($this->base, ['body' => str_repeat('a', 501)])->assertSessionHasErrors('body');
        $this->actingAs($this->manager)->post($this->base, ['body' => "\u{0001}\u{0002}"])->assertSessionHasErrors('body');
        $this->actingAs($this->manager)->post($this->base, ['body' => 'x', 'starts_at' => 'tomorrow'])->assertSessionHasErrors('starts_at');
        $this->actingAs($this->manager)->post($this->base, [
            'body' => 'x', 'starts_at' => '2026-12-02T10:00', 'ends_at' => '2026-12-01T10:00',
        ])->assertSessionHasErrors('ends_at');

        $this->assertDatabaseCount('mosque_display_messages', 0);
    }

    public function test_the_list_has_a_limit(): void
    {
        config(['display.max_messages' => 2]);
        $this->actingAs($this->manager)->post($this->base, ['body' => 'One']);
        $this->actingAs($this->manager)->post($this->base, ['body' => 'Two']);
        $this->actingAs($this->manager)->post($this->base, ['body' => 'Three'])->assertSessionHasErrors('body');

        $this->assertDatabaseCount('mosque_display_messages', 2);
    }

    public function test_managers_edit_pause_reorder_and_delete(): void
    {
        foreach (['First', 'Second', 'Third'] as $body) {
            $this->actingAs($this->manager)->post($this->base, ['body' => $body]);
        }
        [$first, $second, $third] = MosqueDisplayMessage::query()->orderBy('sort')->get()->all();

        $this->actingAs($this->manager)->put("{$this->base}/{$second->id}", ['body' => 'Second, edited', 'active' => false])
            ->assertSessionHasNoErrors();
        $this->assertSame('Second, edited', $second->fresh()->body);
        $this->assertFalse($second->fresh()->active);

        $this->actingAs($this->manager)->put("{$this->base}/order", ['ids' => [$third->id, $first->id, $second->id]])
            ->assertSessionHasNoErrors();
        $this->assertSame(['Third', 'First', 'Second, edited'], MosqueDisplayMessage::query()->orderBy('sort')->pluck('body')->all());

        $this->actingAs($this->manager)->delete("{$this->base}/{$first->id}")->assertRedirect();
        $this->assertModelMissing($first);
    }

    public function test_editing_a_paused_message_keeps_it_paused(): void
    {
        $this->actingAs($this->manager)->post($this->base, ['body' => 'Quiet', 'active' => false]);
        $message = MosqueDisplayMessage::query()->sole();
        $this->assertFalse($message->active);

        $this->actingAs($this->manager)->put("{$this->base}/{$message->id}", ['body' => 'Quiet, edited'])
            ->assertSessionHasNoErrors();

        $this->assertSame('Quiet, edited', $message->fresh()->body);
        $this->assertFalse($message->fresh()->active);
    }

    public function test_reordering_needs_the_whole_list(): void
    {
        foreach (['First', 'Second', 'Third'] as $body) {
            $this->actingAs($this->manager)->post($this->base, ['body' => $body]);
        }
        [$first, $second, $third] = MosqueDisplayMessage::query()->orderBy('sort')->get()->all();

        // Only part of the list would leave two messages at one place.
        $this->actingAs($this->manager)->put("{$this->base}/order", ['ids' => [$third->id, $first->id]])
            ->assertSessionHasErrors('ids');
        $this->actingAs($this->manager)->put("{$this->base}/order", ['ids' => [$third->id, $first->id, $first->id]])
            ->assertSessionHasErrors('ids.1');

        $this->assertSame(['First', 'Second', 'Third'], MosqueDisplayMessage::query()->orderBy('sort')->pluck('body')->all());
        $this->assertSame([1, 2, 3], [$first->fresh()->sort, $second->fresh()->sort, $third->fresh()->sort]);
    }

    public function test_messages_of_another_mosque_are_out_of_reach(): void
    {
        $other = Mosque::factory()->create();
        $foreign = new MosqueDisplayMessage;
        $foreign->forceFill(['mosque_id' => $other->id, 'body' => 'Theirs'])->save();

        $this->actingAs($this->manager)->put("{$this->base}/{$foreign->id}", ['body' => 'Mine now'])->assertNotFound();
        $this->actingAs($this->manager)->delete("{$this->base}/{$foreign->id}")->assertNotFound();
        $this->actingAs($this->manager)->put("{$this->base}/order", ['ids' => [$foreign->id]])->assertSessionHasErrors('ids');

        $this->assertSame('Theirs', $foreign->fresh()->body);
        $this->actingAs($this->manager)->put("{$this->base}/99999999999999999999", ['body' => 'x'])->assertNotFound();
    }
}
