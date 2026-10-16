<?php

namespace Tests\Feature\Claims;

use App\Models\Mosque;
use App\Models\MosqueClaim;
use App\Models\User;
use App\Notifications\ClaimSubmitted;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Notification;
use Illuminate\Support\Facades\Storage;
use Inertia\Testing\AssertableInertia as Assert;
use PHPUnit\Framework\Attributes\DataProvider;
use Tests\TestCase;

class ClaimSubmissionTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        $this->withoutVite(); // pages are checked as Inertia responses, not built assets
        Storage::fake('local');
        Storage::fake('public');
        Notification::fake();
    }

    private function url(Mosque $mosque): string
    {
        return '/mosques/'.$mosque->slug.'/claim';
    }

    public function test_guests_are_sent_to_the_login_page(): void
    {
        $mosque = Mosque::factory()->create();

        $this->get($this->url($mosque))->assertRedirect(route('login'));
        $this->post($this->url($mosque), ['role_at_mosque' => 'Imam'])->assertRedirect(route('login'));
        $this->assertDatabaseCount('mosque_claims', 0);
    }

    public function test_unverified_users_must_verify_their_email_first(): void
    {
        $mosque = Mosque::factory()->create();
        $user = User::factory()->unverified()->create();

        $this->actingAs($user)->get($this->url($mosque))->assertRedirect(route('verification.notice'));
        $this->actingAs($user)->post($this->url($mosque), ['role_at_mosque' => 'Imam'])
            ->assertRedirect(route('verification.notice'));
        $this->assertDatabaseCount('mosque_claims', 0);
    }

    public function test_a_verified_user_sees_the_request_form(): void
    {
        $mosque = Mosque::factory()->withCalendar()->create();

        $this->actingAs(User::factory()->create())
            ->get($this->url($mosque))
            ->assertOk()
            ->assertInertia(fn (Assert $page) => $page
                ->component('claims/create')
                ->where('mosque.slug', $mosque->slug)
                ->where('mosque.has_times', true)
                ->where('manages', false)
                ->where('pendingClaim', null)
                ->where('documentMaxMb', 8));
    }

    public function test_the_form_page_shows_a_pending_request_instead_of_the_form(): void
    {
        $user = User::factory()->create();
        $claim = MosqueClaim::factory()->for($user)->create();

        $this->actingAs($user)
            ->get($this->url($claim->mosque))
            ->assertInertia(fn (Assert $page) => $page
                ->component('claims/create')
                ->where('pendingClaim.id', $claim->id));
    }

    public function test_unknown_or_malformed_mosques_are_not_found(): void
    {
        $user = User::factory()->create();

        $this->actingAs($user)->get('/mosques/does-not-exist/claim')->assertNotFound();
        $this->actingAs($user)->get('/mosques/Bad_Slug/claim')->assertNotFound();
    }

    public function test_a_user_can_send_a_request_with_a_private_document(): void
    {
        $mosque = Mosque::factory()->create();
        $user = User::factory()->create();
        $admin = User::factory()->create(['locale' => 'fr']);
        $admin->forceFill(['is_admin' => true])->save();

        $response = $this->actingAs($user)->post($this->url($mosque), [
            'role_at_mosque' => '  Président de l\'association ',
            'phone' => '+33 6 12 34 56 78',
            'message' => 'Je suis le président depuis 2019.',
            'document' => UploadedFile::fake()->create('statuts.pdf', 600, 'application/pdf'),
        ]);

        $response->assertRedirect(route('claims.mine'));
        $response->assertInertiaFlash('toast.type', 'success');

        $claim = MosqueClaim::query()->sole();
        $this->assertSame($user->id, $claim->user_id);
        $this->assertSame($mosque->id, $claim->mosque_id);
        $this->assertSame(MosqueClaim::PENDING, $claim->status);
        $this->assertSame('Président de l\'association', $claim->role_at_mosque);
        $this->assertSame('+33 6 12 34 56 78', $claim->phone);

        // Stored on the private disk under claims/{id}/, never on the public one.
        $this->assertStringStartsWith('claims/'.$claim->id.'/', $claim->document_path);
        $this->assertStringEndsWith('.pdf', $claim->document_path);
        Storage::disk('local')->assertExists($claim->document_path);
        $this->assertSame([], Storage::disk('public')->allFiles());

        Notification::assertSentTo($admin, ClaimSubmitted::class, fn (ClaimSubmitted $n) => $n->locale === 'fr'
            && $n->claim->is($claim));
        Notification::assertNotSentTo($user, ClaimSubmitted::class);
    }

    public function test_a_request_without_document_or_phone_is_accepted(): void
    {
        $mosque = Mosque::factory()->create();

        $this->actingAs(User::factory()->create())
            ->post($this->url($mosque), ['role_at_mosque' => 'Imam'])
            ->assertRedirect(route('claims.mine'));

        $claim = MosqueClaim::query()->sole();
        $this->assertNull($claim->document_path);
        $this->assertNull($claim->phone);
        $this->assertSame([], Storage::disk('local')->allFiles());
    }

    public function test_roles_written_in_any_script_are_accepted(): void
    {
        $mosque = Mosque::factory()->create();

        // Arabic, and Persian with its zero-width non-joiner (a format character, not a control one).
        $this->actingAs(User::factory()->create())
            ->post($this->url($mosque), ['role_at_mosque' => "إمام وخطيب الجمعة \u{200C}مسئول"])
            ->assertSessionHasNoErrors()
            ->assertRedirect(route('claims.mine'));

        $this->assertSame("إمام وخطيب الجمعة \u{200C}مسئول", MosqueClaim::query()->sole()->role_at_mosque);
    }

    /** @return array<string, array{array<string, mixed>, string}> */
    public static function invalidRequests(): array
    {
        return [
            'role missing' => [['role_at_mosque' => ''], 'role_at_mosque'],
            'role too long' => [['role_at_mosque' => str_repeat('a', 121)], 'role_at_mosque'],
            'role as an array' => [['role_at_mosque' => ['Imam']], 'role_at_mosque'],
            'role on several lines' => [['role_at_mosque' => "Imam\n\n# Approve now"], 'role_at_mosque'],
            'role with a bidi override' => [['role_at_mosque' => "Imam \u{202E}tnediserP"], 'role_at_mosque'],
            'phone with letters' => [['role_at_mosque' => 'Imam', 'phone' => 'call me maybe'], 'phone'],
            'phone too long' => [['role_at_mosque' => 'Imam', 'phone' => str_repeat('1', 41)], 'phone'],
            'message too long' => [['role_at_mosque' => 'Imam', 'message' => str_repeat('a', 2001)], 'message'],
        ];
    }

    #[DataProvider('invalidRequests')]
    public function test_invalid_requests_are_refused(array $data, string $field): void
    {
        $mosque = Mosque::factory()->create();

        $this->actingAs(User::factory()->create())
            ->from($this->url($mosque))
            ->post($this->url($mosque), $data)
            ->assertSessionHasErrors($field);

        $this->assertDatabaseCount('mosque_claims', 0);
    }

    public function test_documents_must_be_a_small_pdf_or_image(): void
    {
        $mosque = Mosque::factory()->create();
        $user = User::factory()->create();

        $this->actingAs($user)->post($this->url($mosque), [
            'role_at_mosque' => 'Imam',
            'document' => UploadedFile::fake()->create('script.php', 10, 'application/x-php'),
        ])->assertSessionHasErrors('document');

        $this->actingAs($user)->post($this->url($mosque), [
            'role_at_mosque' => 'Imam',
            'document' => UploadedFile::fake()->create('huge.pdf', 9000, 'application/pdf'),
        ])->assertSessionHasErrors('document');

        $this->actingAs($user)->post($this->url($mosque), [
            'role_at_mosque' => 'Imam',
            'document' => UploadedFile::fake()->create('scan.png', 300, 'image/png'),
        ])->assertSessionHasNoErrors();

        $this->assertSame(1, MosqueClaim::query()->count());
        $this->assertStringEndsWith('.png', MosqueClaim::query()->sole()->document_path);
    }

    public function test_a_second_pending_request_for_the_same_mosque_is_refused(): void
    {
        $user = User::factory()->create();
        $claim = MosqueClaim::factory()->for($user)->create();

        $this->actingAs($user)
            ->post($this->url($claim->mosque), ['role_at_mosque' => 'Imam'])
            ->assertRedirect(route('claims.mine'))
            ->assertInertiaFlash('toast.type', 'error');

        $this->assertSame(1, MosqueClaim::query()->count());
        Notification::assertNothingSent();
    }

    public function test_a_new_request_is_possible_after_a_rejection(): void
    {
        $user = User::factory()->create();
        $old = MosqueClaim::factory()->for($user)->create(['status' => MosqueClaim::REJECTED]);

        $this->actingAs($user)
            ->post($this->url($old->mosque), ['role_at_mosque' => 'Secrétaire'])
            ->assertRedirect(route('claims.mine'))
            ->assertInertiaFlash('toast.type', 'success');

        $this->assertSame(1, MosqueClaim::query()->where('status', MosqueClaim::PENDING)->count());
    }

    public function test_people_who_already_manage_the_mosque_cannot_claim_it(): void
    {
        $mosque = Mosque::factory()->create();
        $user = User::factory()->create();
        $mosque->managers()->attach($user->id, ['role' => 'owner']);

        $this->actingAs($user)
            ->get($this->url($mosque))
            ->assertInertia(fn (Assert $page) => $page->where('manages', true));

        $this->actingAs($user)
            ->post($this->url($mosque), ['role_at_mosque' => 'Imam'])
            ->assertRedirect(route('claims.mine'))
            ->assertInertiaFlash('toast.type', 'error');

        $this->assertDatabaseCount('mosque_claims', 0);
    }

    public function test_submissions_are_throttled(): void
    {
        $user = User::factory()->create();
        $mosques = Mosque::factory()->count(4)->create();

        foreach ($mosques->take(3) as $mosque) {
            $this->actingAs($user)->post($this->url($mosque), ['role_at_mosque' => 'Imam'])->assertRedirect();
        }

        $this->actingAs($user)->post($this->url($mosques->last()), ['role_at_mosque' => 'Imam'])->assertTooManyRequests();
        $this->assertSame(3, MosqueClaim::query()->count());
    }
}
