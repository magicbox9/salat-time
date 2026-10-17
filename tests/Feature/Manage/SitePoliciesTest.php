<?php

namespace Tests\Feature\Manage;

use App\Models\Mosque;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Gate;
use Tests\Feature\MosqueSite\BuildsMosqueSites;
use Tests\TestCase;

/** Pages and categories follow their own mosque: rights come from the database only. */
class SitePoliciesTest extends TestCase
{
    use BuildsMosqueSites, RefreshDatabase;

    public function test_pages_and_categories_are_managed_by_their_mosque_s_managers_and_admins(): void
    {
        $mosque = Mosque::factory()->create();
        $manager = $this->managerOf($mosque);
        $other = Mosque::factory()->create();
        $records = [
            'own page' => [$this->sitePage($mosque), true],
            'own category' => [$this->category($mosque, 'Khutbah', 'khutbah'), true],
            'foreign page' => [$this->sitePage($other), false],
            'foreign category' => [$this->category($other, 'Khutbah', 'khutbah'), false],
        ];

        foreach ($records as $label => [$record, $allowed]) {
            foreach (['update', 'delete'] as $ability) {
                $this->assertSame($allowed, Gate::forUser($manager)->allows($ability, $record), "$label: $ability");
                $this->assertTrue(Gate::forUser($this->admin())->allows($ability, $record), "admin: $label");
                $this->assertFalse(Gate::forUser(User::factory()->create())->allows($ability, $record), "visitor: $label");
            }
        }
    }
}
