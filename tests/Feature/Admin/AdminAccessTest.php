<?php

namespace Tests\Feature\Admin;

use App\Models\Mosque;
use App\Models\MosqueClaim;
use App\Models\MosquePost;
use App\Models\PostComment;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Notification;
use Inertia\Testing\AssertableInertia as Assert;
use PHPUnit\Framework\Attributes\DataProvider;
use Tests\TestCase;

class AdminAccessTest extends TestCase
{
    use CreatesAdmins, RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        $this->withoutVite(); // pages are checked as Inertia responses, not built assets
    }

    /** @return array<string, array{string, string}> */
    public static function adminEndpoints(): array
    {
        return [
            'overview' => ['get', '/admin'],
            'claims' => ['get', '/admin/claims'],
            'claim' => ['get', '/admin/claims/{claim}'],
            'approve' => ['post', '/admin/claims/{claim}/approve'],
            'reject' => ['post', '/admin/claims/{claim}/reject'],
            'mosques' => ['get', '/admin/mosques'],
            'mosque' => ['get', '/admin/mosques/{mosque}'],
            'update mosque' => ['patch', '/admin/mosques/{mosque}'],
            'verify' => ['post', '/admin/mosques/{mosque}/verify'],
            'unverify' => ['delete', '/admin/mosques/{mosque}/verify'],
            'revoke manager' => ['delete', '/admin/mosques/{mosque}/managers/{user}'],
            'users' => ['get', '/admin/users'],
            'grant admin' => ['post', '/admin/users/{user}/admin'],
            'revoke admin' => ['delete', '/admin/users/{user}/admin'],
        ];
    }

    /** @return array{string, MosqueClaim, User} */
    private function target(string $uri): array
    {
        $claim = MosqueClaim::factory()->create();
        $manager = User::factory()->create();
        $claim->mosque->managers()->attach($manager->id, ['role' => 'owner']);

        return [
            strtr($uri, ['{claim}' => $claim->id, '{mosque}' => $claim->mosque->slug, '{user}' => $manager->id]),
            $claim,
            $manager,
        ];
    }

    #[DataProvider('adminEndpoints')]
    public function test_guests_are_sent_to_the_login_page(string $method, string $uri): void
    {
        [$url] = $this->target($uri);

        $this->{$method}($url, ['note' => 'x'])->assertRedirect(route('login'));
    }

    #[DataProvider('adminEndpoints')]
    public function test_non_admins_are_forbidden(string $method, string $uri): void
    {
        Notification::fake();
        [$url, $claim, $manager] = $this->target($uri);
        $user = User::factory()->create();

        $this->actingAs($user)->{$method}($url, ['note' => 'Pas de justificatif', 'name' => 'Hijack'])->assertForbidden();

        // Nothing changed.
        $this->assertSame(MosqueClaim::PENDING, $claim->fresh()->status);
        $this->assertTrue($manager->manages($claim->mosque));
        $this->assertNull($claim->mosque->fresh()->verified_at);
        $this->assertFalse($user->fresh()->is_admin);
        $this->assertFalse($manager->fresh()->is_admin);
        Notification::assertNothingSent();
    }

    public function test_a_mosque_manager_is_not_an_admin(): void
    {
        [, $claim, $manager] = $this->target('/admin');

        $this->actingAs($manager)->get('/admin')->assertForbidden();
        $this->actingAs($manager)->post('/admin/mosques/'.$claim->mosque->slug.'/verify')->assertForbidden();
    }

    public function test_admins_see_the_overview_with_platform_figures(): void
    {
        $admin = $this->createAdmin();
        Mosque::factory()->withCalendar()->verified()->create();
        Mosque::factory()->create();
        $pending = MosqueClaim::factory()->create();
        MosqueClaim::factory()->create(['status' => MosqueClaim::REJECTED]);
        $post = MosquePost::factory()->create();
        PostComment::factory()->count(2)->create(['post_id' => $post->id]);

        $this->actingAs($admin)
            ->get('/admin')
            ->assertOk()
            ->assertInertia(fn (Assert $page) => $page
                ->component('admin/index')
                ->where('stats.mosques', Mosque::query()->count())
                ->where('stats.mosques_with_times', 1)
                ->where('stats.mosques_verified', 1)
                ->where('stats.claims_pending', 1)
                ->where('stats.admins', 1)
                ->where('stats.posts', 1)
                ->where('stats.comments', 2)
                ->where('pendingClaimsCount', 1)
                ->has('pendingClaims', 1)
                ->where('pendingClaims.0.id', $pending->id));
    }

    public function test_admin_rights_are_read_from_the_database_on_every_request(): void
    {
        $admin = $this->createAdmin();
        $this->actingAs($admin)->get('/admin')->assertOk();

        $admin->forceFill(['is_admin' => false])->save();
        $this->actingAs($admin->fresh())->get('/admin')->assertForbidden();
    }

    public function test_unverified_admins_must_verify_their_email(): void
    {
        $admin = $this->createAdmin(['email_verified_at' => null]);

        $this->actingAs($admin)->get('/admin')->assertRedirect(route('verification.notice'));
    }
}
