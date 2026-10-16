<?php

namespace Tests\Feature\Claims;

use App\Models\Mosque;
use App\Models\MosqueClaim;
use App\Models\User;
use App\Notifications\ClaimApproved;
use App\Notifications\ClaimRejected;
use App\Notifications\ClaimSubmitted;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Mail\Markdown;
use Tests\TestCase;

/**
 * The claim emails are Markdown. Text typed by people (a claimant's name and
 * role, a mosque name, an admin's note) must show as typed and never become a
 * link, an image or a heading in an admin's or a claimant's inbox.
 */
class ClaimEmailTest extends TestCase
{
    use RefreshDatabase;

    private const LINK = '[Approve it here](https://evil.example/login)';

    private const IMAGE = '![pixel](https://track.example/p.png)';

    public function test_claimant_text_cannot_inject_links_or_images_into_the_admin_email(): void
    {
        $claimant = User::factory()->create(['name' => '# '.self::IMAGE]);
        $claim = MosqueClaim::factory()->for($claimant)->create([
            'role_at_mosque' => 'Imam **now** <b>bold</b> '.self::LINK,
        ]);
        $admin = User::factory()->create(['name' => 'Admin']);

        $mail = (new ClaimSubmitted($claim))->toMail($admin);
        $html = (string) $mail->render();

        $this->assertStringNotContainsString('https://evil.example', $this->hrefs($html));
        $this->assertStringNotContainsString('<img src="https://track.example', $html);
        $this->assertStringNotContainsString('<strong>now</strong>', $html);
        $this->assertStringNotContainsString('<b>bold</b>', $html);
        // The text still reads exactly as it was typed.
        $this->assertStringContainsString(e(self::LINK), $html);
        $this->assertStringContainsString(e(self::IMAGE), $html);
        $this->assertStringContainsString('Imam **now** &lt;b&gt;bold&lt;/b&gt;', $html);
    }

    public function test_the_plain_text_part_shows_the_text_unescaped(): void
    {
        $claim = MosqueClaim::factory()->create(['role_at_mosque' => 'Imam & '.self::LINK]);
        $admin = User::factory()->create(['name' => "Nour O'Brien-Saïd"]);

        $mail = (new ClaimSubmitted($claim))->toMail($admin);
        $text = (string) app(Markdown::class)->renderText($mail->markdown, $mail->data());
        $html = (string) $mail->render();

        $this->assertStringContainsString('Imam & '.self::LINK, $text);
        $this->assertStringContainsString("Nour O'Brien-Saïd", $text);
        // Entities are decoded once by the Markdown parser, never shown as "&amp;#39;".
        $this->assertStringNotContainsString('&amp;#', $html);
        $this->assertStringNotContainsString('&amp;amp;', $html);
    }

    public function test_mosque_names_and_review_notes_are_shown_as_plain_text(): void
    {
        $mosque = Mosque::factory()->create(['name' => 'Mosquée _Al_ '.self::LINK]);
        $claim = MosqueClaim::factory()->for($mosque)->create([
            'status' => MosqueClaim::REJECTED,
            'review_note' => "First line\n\n".self::IMAGE,
        ]);

        $html = (string) (new ClaimRejected($claim))->toMail($claim->user)->render();

        $this->assertStringNotContainsString('https://evil.example', $this->hrefs($html));
        $this->assertStringNotContainsString('<img src="https://track.example', $html);
        $this->assertStringNotContainsString('<em>Al</em>', $html);
        $this->assertStringContainsString('First line', $html);
        $this->assertStringContainsString(e(self::IMAGE), $html);

        $claim->forceFill(['status' => MosqueClaim::APPROVED, 'review_note' => self::LINK])->save();
        $html = (string) (new ClaimApproved($claim))->toMail($claim->user)->render();

        $this->assertStringNotContainsString('https://evil.example', $this->hrefs($html));
        $this->assertStringContainsString(e(self::LINK), $html);
    }

    /** Every href of the rendered email, one per line. */
    private function hrefs(string $html): string
    {
        preg_match_all('/href="([^"]*)"/', $html, $matches);

        return implode("\n", $matches[1]);
    }
}
