<?php

namespace Tests\Feature\Content;

use App\Models\QuranBookmark;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Route;
use Tests\TestCase;

class QuranBookmarksTest extends TestCase
{
    use RefreshDatabase;

    public function test_guests_cannot_bookmark(): void
    {
        $this->post('/quran/bookmarks', ['surah' => 2, 'ayah' => 255])->assertRedirect('/login');
        $this->postJson('/quran/bookmarks', ['surah' => 2, 'ayah' => 255])->assertUnauthorized();

        $this->assertDatabaseCount('quran_bookmarks', 0);
    }

    public function test_a_reader_bookmarks_an_ayah(): void
    {
        $user = User::factory()->create();

        $this->actingAs($user)
            ->from('/quran/2')
            ->post('/quran/bookmarks', ['surah' => 2, 'ayah' => 255, 'note' => 'Ayat al-Kursi'])
            ->assertRedirect('/quran/2')
            ->assertSessionHasNoErrors();

        $this->assertDatabaseHas('quran_bookmarks', [
            'user_id' => $user->id, 'surah' => 2, 'ayah' => 255, 'note' => 'Ayat al-Kursi',
        ]);
    }

    public function test_bookmarking_the_same_ayah_again_updates_it(): void
    {
        $user = User::factory()->create();
        $this->actingAs($user);

        $this->postJson('/quran/bookmarks', ['surah' => 18, 'ayah' => 10, 'note' => 'First'])->assertOk();
        // Without a note the existing note is kept…
        $this->postJson('/quran/bookmarks', ['surah' => 18, 'ayah' => 10])->assertOk()->assertJsonPath('note', 'First');
        // …a new note replaces it, and an explicit null clears it.
        $this->postJson('/quran/bookmarks', ['surah' => 18, 'ayah' => 10, 'note' => 'Second'])->assertJsonPath('note', 'Second');
        $this->postJson('/quran/bookmarks', ['surah' => 18, 'ayah' => 10, 'note' => null])->assertJsonPath('note', null);

        $this->assertSame(1, QuranBookmark::where('user_id', $user->id)->count());
    }

    public function test_bookmark_input_is_validated(): void
    {
        $this->actingAs(User::factory()->create());

        $this->postJson('/quran/bookmarks', ['surah' => 115, 'ayah' => 1])->assertJsonValidationErrors('surah');
        $this->postJson('/quran/bookmarks', ['surah' => 0, 'ayah' => 1])->assertJsonValidationErrors('surah');
        $this->postJson('/quran/bookmarks', ['surah' => 1, 'ayah' => 8])->assertJsonValidationErrors('ayah');
        $this->postJson('/quran/bookmarks', ['surah' => 114, 'ayah' => 0])->assertJsonValidationErrors('ayah');
        $this->postJson('/quran/bookmarks', ['surah' => 'two', 'ayah' => 'x'])->assertJsonValidationErrors(['surah', 'ayah']);
        $this->postJson('/quran/bookmarks', ['surah' => 2, 'ayah' => 1, 'note' => str_repeat('a', 501)])->assertJsonValidationErrors('note');
        $this->postJson('/quran/bookmarks', ['surah' => 2, 'ayah' => 286])->assertOk();

        $this->assertDatabaseCount('quran_bookmarks', 1);
    }

    public function test_bookmarking_is_rate_limited_on_its_own_counter(): void
    {
        // A route throttled like the password and e-mail verification routes
        // ("throttle:6,1", no prefix): bookmarking must not eat its budget.
        Route::middleware(['web', 'auth', 'throttle:6,1'])->get('/_test/strict-limit', fn () => 'ok');
        $user = User::factory()->create();
        $this->actingAs($user);

        foreach (range(1, 60) as $ayah) {
            $this->postJson('/quran/bookmarks', ['surah' => 2, 'ayah' => $ayah])->assertOk();
        }
        $this->postJson('/quran/bookmarks', ['surah' => 2, 'ayah' => 61])->assertTooManyRequests();

        $this->get('/_test/strict-limit')->assertOk();
        $this->assertSame(60, QuranBookmark::where('user_id', $user->id)->count());
    }

    public function test_a_reader_removes_their_own_bookmark(): void
    {
        $user = User::factory()->create();
        $bookmark = QuranBookmark::create(['user_id' => $user->id, 'surah' => 36, 'ayah' => 1]);

        $this->actingAs($user)->from('/quran')->delete("/quran/bookmarks/{$bookmark->id}")->assertRedirect('/quran');

        $this->assertModelMissing($bookmark);
    }

    public function test_nobody_can_remove_someone_elses_bookmark(): void
    {
        $owner = User::factory()->create();
        $bookmark = QuranBookmark::create(['user_id' => $owner->id, 'surah' => 36, 'ayah' => 1]);

        $this->delete("/quran/bookmarks/{$bookmark->id}")->assertRedirect('/login');
        $this->actingAs(User::factory()->create())->delete("/quran/bookmarks/{$bookmark->id}")->assertForbidden();
        $this->deleteJson('/quran/bookmarks/999999')->assertNotFound();

        $this->assertModelExists($bookmark);
    }
}
