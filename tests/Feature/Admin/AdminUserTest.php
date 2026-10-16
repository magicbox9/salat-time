<?php

namespace Tests\Feature\Admin;

use App\Models\Mosque;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Inertia\Testing\AssertableInertia as Assert;
use Tests\TestCase;

class AdminUserTest extends TestCase
{
    use CreatesAdmins, RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        $this->withoutVite(); // pages are checked as Inertia responses, not built assets
    }

    public function test_the_list_can_be_searched_and_filtered(): void
    {
        $admin = $this->createAdmin(['name' => 'Admin Principal']);
        $manager = User::factory()->create(['name' => 'Fatima Zahra', 'email' => 'fatima@example.org']);
        Mosque::factory()->create()->managers()->attach($manager->id, ['role' => 'owner']);
        User::factory()->unverified()->create(['name' => 'Nouveau Compte']);

        $this->actingAs($admin)
            ->get('/admin/users')
            ->assertOk()
            ->assertInertia(fn (Assert $page) => $page
                ->component('admin/users/index')
                ->where('users.total', 3)
                ->where('adminCount', 1)
                ->missing('users.data.0.password'));

        $this->actingAs($admin)
            ->get('/admin/users?q=FATIMA@')
            ->assertInertia(fn (Assert $page) => $page
                ->where('users.total', 1)
                ->where('users.data.0.id', $manager->id)
                ->where('users.data.0.managed_count', 1));

        $this->actingAs($admin)
            ->get('/admin/users?role=unverified')
            ->assertInertia(fn (Assert $page) => $page->where('users.total', 1)->where('users.data.0.verified', false));

        $this->actingAs($admin)
            ->get('/admin/users?role=admin')
            ->assertInertia(fn (Assert $page) => $page
                ->where('users.total', 1)
                ->where('users.data.0.is_self', true));
    }

    public function test_an_admin_can_grant_admin_rights(): void
    {
        $admin = $this->createAdmin();
        $user = User::factory()->create();

        $this->actingAs($admin)
            ->post('/admin/users/'.$user->id.'/admin')
            ->assertRedirect()
            ->assertInertiaFlash('toast.type', 'success');

        $this->assertTrue($user->fresh()->is_admin);
    }

    public function test_unverified_accounts_cannot_become_admins(): void
    {
        $admin = $this->createAdmin();
        $user = User::factory()->unverified()->create();

        $this->actingAs($admin)
            ->post('/admin/users/'.$user->id.'/admin')
            ->assertInertiaFlash('toast.type', 'error');

        $this->assertFalse($user->fresh()->is_admin);
    }

    public function test_an_admin_can_remove_another_admin(): void
    {
        $admin = $this->createAdmin();
        $other = $this->createAdmin();

        $this->actingAs($admin)
            ->delete('/admin/users/'.$other->id.'/admin')
            ->assertRedirect()
            ->assertInertiaFlash('toast.type', 'success');

        $this->assertFalse($other->fresh()->is_admin);
        $this->assertTrue($admin->fresh()->is_admin);
    }

    public function test_an_admin_cannot_remove_their_own_rights(): void
    {
        $admin = $this->createAdmin();
        $this->createAdmin();

        $this->actingAs($admin)
            ->delete('/admin/users/'.$admin->id.'/admin')
            ->assertInertiaFlash('toast.message', ui('admin.error_self_admin'));

        $this->assertTrue($admin->fresh()->is_admin);
    }

    public function test_the_last_admin_cannot_be_removed(): void
    {
        $admin = $this->createAdmin();

        $this->actingAs($admin)
            ->delete('/admin/users/'.$admin->id.'/admin')
            ->assertInertiaFlash('toast.message', ui('admin.error_last_admin'));

        $this->assertTrue($admin->fresh()->is_admin);
        $this->assertSame(1, User::query()->where('is_admin', true)->count());
    }

    public function test_is_admin_cannot_be_set_through_the_profile_form(): void
    {
        $user = User::factory()->create();

        $this->actingAs($user)->patch('/settings/profile', [
            'name' => $user->name,
            'email' => $user->email,
            'is_admin' => true,
        ]);

        $this->assertFalse($user->fresh()->is_admin);
    }
}
