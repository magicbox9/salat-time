<?php

namespace Tests\Feature\Admin;

use App\Models\Mosque;
use App\Models\MosqueClaim;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Inertia\Testing\AssertableInertia as Assert;
use PHPUnit\Framework\Attributes\DataProvider;
use Tests\TestCase;

class AdminMosqueTest extends TestCase
{
    use CreatesAdmins, RefreshDatabase;

    private User $admin;

    protected function setUp(): void
    {
        parent::setUp();
        $this->withoutVite(); // pages are checked as Inertia responses, not built assets
        $this->admin = $this->createAdmin();
    }

    /** @return array<string, mixed> */
    private function validData(array $overrides = []): array
    {
        return [
            'name' => 'Mosquée Al-Rahma',
            'address' => '12 rue de la Paix',
            'postcode' => '69003',
            'city' => 'Lyon',
            'latitude' => '45.7578',
            'longitude' => '4.8320',
            'timezone' => 'Europe/Paris',
            ...$overrides,
        ];
    }

    public function test_the_list_can_be_filtered(): void
    {
        $withTimes = Mosque::factory()->withCalendar()->create(['name' => 'Mosquée Ennour', 'city' => 'Lyon']);
        $verified = Mosque::factory()->verified()->create(['source' => 'osm', 'name' => 'Salle de prière Assalam']);
        Mosque::factory()->create(['source' => 'directory']);

        $this->actingAs($this->admin)
            ->get('/admin/mosques')
            ->assertOk()
            ->assertInertia(fn (Assert $page) => $page
                ->component('admin/mosques/index')
                ->where('mosques.total', 3)
                ->has('sources', 4));

        $this->actingAs($this->admin)
            ->get('/admin/mosques?times=yes')
            ->assertInertia(fn (Assert $page) => $page
                ->where('mosques.total', 1)
                ->where('mosques.data.0.id', $withTimes->id)
                ->where('mosques.data.0.has_times', true));

        $this->actingAs($this->admin)
            ->get('/admin/mosques?times=no&verified=yes')
            ->assertInertia(fn (Assert $page) => $page
                ->where('mosques.total', 1)
                ->where('mosques.data.0.id', $verified->id));

        $this->actingAs($this->admin)
            ->get('/admin/mosques?source=osm')
            ->assertInertia(fn (Assert $page) => $page->where('mosques.total', 1));

        $this->actingAs($this->admin)
            ->get('/admin/mosques?q=ennour')
            ->assertInertia(fn (Assert $page) => $page->where('mosques.data.0.id', $withTimes->id));

        // Unknown values are ignored instead of failing.
        $this->actingAs($this->admin)
            ->get('/admin/mosques?source=evil&times[]=x')
            ->assertOk()
            ->assertInertia(fn (Assert $page) => $page->where('filters.source', null)->where('mosques.total', 3));
    }

    public function test_the_edit_page_lists_managers_and_pending_requests(): void
    {
        $mosque = Mosque::factory()->create();
        $manager = User::factory()->create();
        $mosque->managers()->attach($manager->id, ['role' => 'owner', 'granted_by' => $this->admin->id]);
        MosqueClaim::factory()->create(['mosque_id' => $mosque->id]);

        $this->actingAs($this->admin)
            ->get('/admin/mosques/'.$mosque->slug)
            ->assertOk()
            ->assertInertia(fn (Assert $page) => $page
                ->component('admin/mosques/edit')
                ->where('mosque.slug', $mosque->slug)
                ->has('managers', 1)
                ->where('managers.0.granted_by', $this->admin->name)
                ->has('pendingClaims', 1)
                ->has('timezones'));
    }

    public function test_an_admin_can_correct_a_mosque(): void
    {
        $mosque = Mosque::factory()->create(['timezone' => 'Europe/Paris']);

        $this->actingAs($this->admin)
            ->patch('/admin/mosques/'.$mosque->slug, $this->validData(['timezone' => 'Indian/Reunion', 'address' => '  ']))
            ->assertRedirect(route('admin.mosques.edit', $mosque))
            ->assertInertiaFlash('toast.type', 'success');

        $mosque->refresh();
        $this->assertSame('Mosquée Al-Rahma', $mosque->name);
        $this->assertNull($mosque->address);
        $this->assertSame('Lyon', $mosque->city);
        $this->assertSame(45.7578, $mosque->latitude);
        $this->assertSame(4.832, $mosque->longitude);
        $this->assertSame('Indian/Reunion', $mosque->timezone);
        $this->assertSame('mosquee al-rahma lyon', $mosque->search_name);
    }

    public function test_a_legacy_time_zone_stays_selected_and_can_be_saved(): void
    {
        // Europe/Kiev is a backward-compatible alias, absent from the current zone list.
        $mosque = Mosque::factory()->create(['timezone' => 'Europe/Kiev']);

        $this->actingAs($this->admin)
            ->get('/admin/mosques/'.$mosque->slug)
            ->assertInertia(fn (Assert $page) => $page
                ->where('timezones.0', 'Europe/Kiev')
                ->where('mosque.timezone', 'Europe/Kiev'));

        $this->actingAs($this->admin)
            ->patch('/admin/mosques/'.$mosque->slug, $this->validData(['timezone' => 'Europe/Kiev']))
            ->assertSessionHasNoErrors();

        $this->assertSame('Europe/Kiev', $mosque->fresh()->timezone);

        // A current zone is listed once, in its usual place.
        $paris = Mosque::factory()->create(['timezone' => 'Europe/Paris']);
        $this->actingAs($this->admin)
            ->get('/admin/mosques/'.$paris->slug)
            ->assertInertia(fn (Assert $page) => $page->where('timezones.0', 'Africa/Abidjan'));
    }

    /** @return array<string, array{array<string, mixed>, string}> */
    public static function invalidMosques(): array
    {
        return [
            'name missing' => [['name' => ''], 'name'],
            'name too long' => [['name' => str_repeat('a', 201)], 'name'],
            'latitude out of range' => [['latitude' => '95'], 'latitude'],
            'longitude out of range' => [['longitude' => '-181'], 'longitude'],
            'latitude not a number' => [['latitude' => 'north'], 'latitude'],
            'unknown time zone' => [['timezone' => 'Mars/Olympus'], 'timezone'],
            'postcode too long' => [['postcode' => str_repeat('9', 17)], 'postcode'],
        ];
    }

    #[DataProvider('invalidMosques')]
    public function test_invalid_corrections_are_refused(array $overrides, string $field): void
    {
        $mosque = Mosque::factory()->create(['name' => 'Avant']);

        $this->actingAs($this->admin)
            ->patch('/admin/mosques/'.$mosque->slug, $this->validData($overrides))
            ->assertSessionHasErrors($field);

        $this->assertSame('Avant', $mosque->fresh()->name);
    }

    public function test_verification_can_be_set_and_cleared(): void
    {
        $mosque = Mosque::factory()->create();

        $this->actingAs($this->admin)
            ->post('/admin/mosques/'.$mosque->slug.'/verify')
            ->assertRedirect()
            ->assertInertiaFlash('toast.type', 'success');
        $this->assertNotNull($verifiedAt = $mosque->fresh()->verified_at);

        // Verifying again keeps the original date.
        $this->travel(2)->days();
        $this->actingAs($this->admin)->post('/admin/mosques/'.$mosque->slug.'/verify');
        $this->assertTrue($verifiedAt->equalTo($mosque->fresh()->verified_at));

        $this->actingAs($this->admin)->delete('/admin/mosques/'.$mosque->slug.'/verify')->assertRedirect();
        $this->assertNull($mosque->fresh()->verified_at);
    }

    public function test_a_manager_can_be_removed(): void
    {
        $mosque = Mosque::factory()->create();
        $manager = User::factory()->create();
        $other = Mosque::factory()->create();
        $mosque->managers()->attach($manager->id, ['role' => 'owner']);
        $other->managers()->attach($manager->id, ['role' => 'owner']);

        $this->actingAs($this->admin)
            ->delete('/admin/mosques/'.$mosque->slug.'/managers/'.$manager->id)
            ->assertRedirect()
            ->assertInertiaFlash('toast.type', 'success');

        $this->assertFalse($manager->manages($mosque));
        $this->assertTrue($manager->manages($other));
    }

    public function test_removing_someone_who_does_not_manage_the_mosque_is_not_found(): void
    {
        $mosque = Mosque::factory()->create();
        $user = User::factory()->create();

        $this->actingAs($this->admin)
            ->delete('/admin/mosques/'.$mosque->slug.'/managers/'.$user->id)
            ->assertNotFound();
    }
}
