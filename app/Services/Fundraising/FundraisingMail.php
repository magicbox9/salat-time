<?php

namespace App\Services\Fundraising;

use App\Models\Campaign;
use App\Models\Donation;
use App\Models\Mosque;
use App\Models\User;
use App\Notifications\CampaignNotification;
use App\Notifications\DonationBankInstructions;
use App\Notifications\DonationThanks;
use App\Support\Ui;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Notification;

/**
 * Who receives which fundraising email, in which language: donors in the
 * language they gave in (or their account's), managers and admins in their
 * account's language.
 */
class FundraisingMail
{
    public function thank(Donation $donation): void
    {
        $this->toDonor($donation, new DonationThanks($donation));
    }

    public function bankInstructions(Donation $donation): void
    {
        $this->toDonor($donation, new DonationBankInstructions($donation));
    }

    /** Every manager of the mosque (owners and editors). */
    public function toManagers(Mosque $mosque, CampaignNotification $notification): void
    {
        User::query()
            ->whereIn('id', DB::table('mosque_managers')->where('mosque_id', $mosque->id)->select('user_id'))
            ->get(['id', 'name', 'email', 'locale'])
            ->each(fn (User $manager) => $manager->notify((clone $notification)->locale($this->locale($manager->locale))));
    }

    public function toAdmins(CampaignNotification $notification): void
    {
        User::query()->where('is_admin', true)->get(['id', 'name', 'email', 'locale'])
            ->each(fn (User $admin) => $admin->notify((clone $notification)->locale($this->locale($admin->locale))));
    }

    /** Managers learn the decision on their campaign. */
    public function decision(Campaign $campaign, CampaignNotification $notification): void
    {
        $mosque = Mosque::query()->find($campaign->mosque_id);
        if ($mosque) {
            $this->toManagers($mosque, $notification);
        }
    }

    private function toDonor(Donation $donation, CampaignNotification $notification): void
    {
        $email = $donation->donor_email;
        if (! is_string($email) || $email === '') {
            return;
        }

        $locale = $donation->getAttribute('locale');
        if (! is_string($locale) && $donation->user_id) {
            $locale = User::query()->whereKey($donation->user_id)->value('locale');
        }
        $locale = $this->locale(is_string($locale) ? $locale : null);
        Notification::route('mail', [$email => (string) $donation->donor_name ?: $email])
            ->notify($notification->locale($locale));
    }

    private function locale(?string $locale): string
    {
        return is_string($locale) && array_key_exists($locale, Ui::LOCALES) ? $locale : (string) config('app.locale', 'en');
    }
}
