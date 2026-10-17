<?php

namespace Tests\Feature\Fundraising;

use App\Models\Campaign;
use App\Models\Donation;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class TidyFundraisingTest extends TestCase
{
    use RefreshDatabase;

    public function test_stale_bank_pledges_expire_and_ended_campaigns_close(): void
    {
        $campaign = Campaign::factory()->active()->create();
        $stale = Donation::factory()->create(['campaign_id' => $campaign->id, 'method' => 'bank']);
        $stale->forceFill(['created_at' => now()->subDays(40)])->save();
        $fresh = Donation::factory()->create(['campaign_id' => $campaign->id, 'method' => 'bank']);
        $ended = Campaign::factory()->active()->create();
        $ended->forceFill(['ends_at' => now()->subDay()])->save();

        $this->artisan('fundraising:tidy')->assertSuccessful();

        $this->assertSame('cancelled', $stale->fresh()->status);
        $this->assertSame('pending', $fresh->fresh()->status);
        $this->assertSame('completed', $ended->fresh()->status);
        $this->assertSame('active', $campaign->fresh()->status);
    }
}
